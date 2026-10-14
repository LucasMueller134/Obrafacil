#!/usr/bin/env python3
"""Treina o modelo próprio de fases da obra do ObraFácil.

O classificador base do ML Kit, que o app usa na foto do diário, foi
treinado em fotos do dia a dia: não conhece forma de laje, baldrame nem
reboco. Este script treina um classificador com as fotos das suas obras,
uma pasta por fase, e exporta um `.tflite` com metadados (rótulos e
normalização) que o app carrega pelo `LocalLabelerOptions` do ML Kit, no
aparelho e sem internet.

Uso (passo a passo completo em docs/ia/treinar-modelo.md):

    # só confere as pastas e monta o dataset, sem treinar
    python treinar.py --dados fotos/ --verificar

    # treina e exporta saida/fases_obra.tflite
    python treinar.py --dados fotos/ --saida saida/

Estrutura esperada de `--dados` (o nome da pasta é a fase; acento,
maiúscula e espaço não importam — "Reboco e contrapiso" vira
`reboco_e_contrapiso`):

    fotos/
      fundacao/            *.jpg (pode ter subpastas, uma por obra)
      estrutura/
      alvenaria/
      ...
      outros/              fotos que não são de nenhuma fase, e as das fases
                           que você não for treinar (obrigatória)

Depende de `mediapipe-model-maker` (testado com 0.2.1.4). O primeiro treino
baixa o modelo base do TF Hub, então precisa de internet — no Google Colab
isso já funciona.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import random
import shutil
import sys
import tempfile
import unicodedata
from pathlib import Path

# As fases do app, na ordem e com a grafia de AppConstants.fasesPadrao
# (obra_facil/lib/constants/app_constants.dart). O rótulo de cada uma no
# modelo é a forma sem acento — é o que ModeloFases.faseDoRotulo espera.
FASES = [
    "Fundação",
    "Estrutura",
    "Alvenaria",
    "Cobertura",
    "Instalações elétricas",
    "Instalações hidráulicas",
    "Reboco e contrapiso",
    "Revestimentos",
    "Pintura",
    "Acabamento",
]

# Classe para o que não é nenhuma fase treinada (selfie, nota fiscal, foto
# do almoço, foto de uma fase que ficou fora do treino). É obrigatória: o
# classificador termina em softmax, então sem ela a maior saída de qualquer
# foto é pelo menos 1/N — com duas fases, sempre 50% ou mais —, e o app
# trata isso como evidência forte e preenche a fase errada. Com ela, o
# modelo aprende a dizer "não sei". O app ignora este rótulo.
OUTROS = "outros"

# Formatos que o Model Maker decodifica: o image_utils.load_image dele usa
# decode_jpeg ou decode_png (que também lê GIF). HEIC (padrão do iPhone),
# WebP e BMP não — o decode_png recusa BMP no meio do treino — e precisam
# ser convertidos para JPEG antes.
EXTENSOES = {".jpg", ".jpeg", ".png", ".gif"}
EXTENSOES_A_CONVERTER = {".heic", ".heif", ".webp", ".bmp"}

# Começo do arquivo de cada formato aceito. A extensão não basta: o "._"
# que o macOS deixa ao lado de cada foto, a foto cortada no meio da cópia
# ou o HEIC renomeado para .jpg também terminam em .jpg, passam no
# --verificar (o Model Maker só lê as fotos no treino) e derrubam o treino.
ASSINATURAS = (b"\xff\xd8\xff", b"\x89PNG\r\n\x1a\n", b"GIF87a", b"GIF89a")

# Abaixo disso o modelo decora as fotos em vez de aprender a fase.
MINIMO_POR_FASE = 30
RECOMENDADO_POR_FASE = 100

MODELOS = {
    "efficientnet_lite0": "EFFICIENTNET_LITE0",
    "mobilenet_v2": "MOBILENET_V2",
    "efficientnet_lite2": "EFFICIENTNET_LITE2",
}

NOME_DO_ARQUIVO = "fases_obra.tflite"


def rotulo_da_fase(nome: str) -> str:
    """'Reboco e contrapiso' -> 'reboco_e_contrapiso' (igual ao app)."""
    sem_acento = "".join(
        c
        for c in unicodedata.normalize("NFD", nome.lower())
        if unicodedata.category(c) != "Mn"
    )
    rotulo = "".join(c if c.isascii() and c.isalnum() else "_" for c in sem_acento)
    while "__" in rotulo:
        rotulo = rotulo.replace("__", "_")
    return rotulo.strip("_")


ROTULOS = {rotulo_da_fase(f): f for f in FASES}


def _pastas_visiveis(pasta: Path) -> list[Path]:
    """Subpastas, sem as de sistema: a __MACOSX que o "Compactar" do macOS
    põe no zip e as ocultas (.Trash, .ipynb_checkpoints)."""
    return sorted(p for p in pasta.iterdir()
                  if p.is_dir() and p.name != "__MACOSX" and not p.name.startswith("."))


def localizar_raiz(origem: Path) -> Path:
    """A pasta que tem as pastas das fases.

    Compactar a pasta fotos/ pelo Windows ou pelo macOS põe a raiz fotos/
    dentro do zip, e o `unzip -d /content/fotos` do guia gera
    /content/fotos/fotos/<fase>/. Quando `origem` não tem nenhuma fase e tem
    uma única subpasta que tem, o dataset está nela.
    """
    def tem_fase(pasta: Path) -> bool:
        return any(rotulo_da_fase(p.name) in ROTULOS or rotulo_da_fase(p.name) == OUTROS
                   for p in _pastas_visiveis(pasta))

    if not origem.is_dir() or tem_fase(origem):
        return origem
    subpastas = _pastas_visiveis(origem)
    if len(subpastas) == 1 and tem_fase(subpastas[0]):
        print(f"  - as fases estão em {subpastas[0]}: usando essa pasta.")
        return subpastas[0]
    return origem


def montar_dataset(origem: Path, destino: Path, classes: list[str] | None = None,
                   do_treino: set[str] | None = None) -> tuple[dict[str, int], set[str]]:
    """Copia as fotos válidas para `destino/<rótulo>/`, uma vez cada.

    O Model Maker lê qualquer arquivo dentro das pastas e para no primeiro
    que não for imagem; e a mesma foto em duas pastas (ou duas vezes na
    mesma) vaza do treino para o teste e infla a acurácia. Por isso o
    dataset é remontado limpo: só imagens, sem repetição, com o nome da
    pasta já normalizado.

    `classes` força a criação das pastas de todas as classes do treino,
    mesmo vazias, para que o índice de cada rótulo seja o mesmo no
    conjunto de teste separado. `do_treino` são os resumos das fotos do
    treino: no teste, foto que o modelo já viu não mede nada.

    Devolve as fotos por classe e o resumo (SHA-1) de cada foto aceita.
    """
    if not origem.is_dir():
        sys.exit(f"Pasta de fotos não encontrada: {origem}")
    origem = localizar_raiz(origem)

    contagem: dict[str, int] = {c: 0 for c in classes or []}
    vistas: dict[str, tuple[str, Path]] = {}
    repetidas = a_converter = ignoradas = ilegiveis = no_treino = 0
    # A mesma foto em duas fases é erro de separação, não só repetição: o
    # modelo aprenderia que aquela cena é as duas coisas.
    em_duas_fases: list[tuple[Path, Path]] = []

    for pasta in _pastas_visiveis(origem):
        rotulo = rotulo_da_fase(pasta.name)
        if rotulo not in ROTULOS and rotulo != OUTROS:
            print(f"  ! pasta '{pasta.name}' não é uma fase do app — ignorada. "
                  f"Fases aceitas: {', '.join(ROTULOS)} e '{OUTROS}'.")
            continue
        if classes is not None and rotulo not in classes:
            print(f"  ! pasta '{pasta.name}' não existe no treino — ignorada no teste.")
            continue
        (destino / rotulo).mkdir(parents=True, exist_ok=True)
        contagem.setdefault(rotulo, 0)

        for arquivo in sorted(pasta.rglob("*")):
            if not arquivo.is_file():
                continue
            extensao = arquivo.suffix.lower()
            if extensao in EXTENSOES_A_CONVERTER:
                a_converter += 1
                continue
            if extensao not in EXTENSOES:
                ignoradas += 1
                continue
            conteudo = arquivo.read_bytes()
            if not conteudo.startswith(ASSINATURAS):
                ilegiveis += 1
                continue
            resumo = hashlib.sha1(conteudo).hexdigest()
            if resumo in vistas:
                rotulo_antes, arquivo_antes = vistas[resumo]
                if rotulo_antes != rotulo:
                    em_duas_fases.append((arquivo_antes, arquivo))
                else:
                    repetidas += 1
                continue
            if do_treino is not None and resumo in do_treino:
                no_treino += 1
                continue
            vistas[resumo] = (rotulo, arquivo)
            (destino / rotulo / f"{resumo}{extensao}").write_bytes(conteudo)
            contagem[rotulo] += 1

    for classe in contagem:
        (destino / classe).mkdir(parents=True, exist_ok=True)
    if repetidas:
        print(f"  - {repetidas} foto(s) repetida(s) entraram uma vez só.")
    if em_duas_fases:
        print(f"  ! {len(em_duas_fases)} foto(s) estão em duas fases; ficou valendo "
              "a primeira. Confira:")
        for antes, depois in em_duas_fases[:5]:
            print(f"      {antes}  =  {depois}")
    if no_treino:
        print(f"  ! {no_treino} foto(s) do teste também estão no treino — "
              "ficaram fora do teste.")
    if a_converter:
        print(f"  ! {a_converter} foto(s) HEIC/WebP/BMP ignorada(s): converta para JPEG.")
    if ilegiveis:
        print(f"  ! {ilegiveis} arquivo(s) com nome de foto que não são JPEG, PNG ou "
              "GIF de verdade (cópia cortada, '._' do macOS, HEIC renomeado) "
              "ignorado(s).")
    if ignoradas:
        print(f"  - {ignoradas} arquivo(s) que não são foto ignorado(s).")
    return contagem, set(vistas)


def conferir(contagem: dict[str, int]) -> bool:
    """Mostra quantas fotos há por classe e diz se dá para treinar."""
    print("\nFotos por classe:")
    for rotulo in sorted(contagem, key=lambda r: (r == OUTROS, r)):
        n = contagem[rotulo]
        nome = ROTULOS.get(rotulo, "(não é fase)")
        aviso = ""
        if n == 0:
            aviso = "  <- vazia: fica fora do treino"
        elif n < MINIMO_POR_FASE:
            aviso = f"  <- pouco: mínimo {MINIMO_POR_FASE}"
        elif n < RECOMENDADO_POR_FASE:
            aviso = f"  <- funciona, mas {RECOMENDADO_POR_FASE}+ é melhor"
        print(f"  {rotulo:<26} {n:>5}  {nome}{aviso}")

    com_fotos = {r: n for r, n in contagem.items() if n > 0}
    if len(com_fotos) < 2:
        print("\nÉ preciso de pelo menos duas classes com fotos para treinar.")
        return False
    if OUTROS not in com_fotos:
        # Recusa em vez de só avisar: o modelo sem "outros" não erra de vez
        # em quando, erra em toda foto que não é das fases treinadas.
        print(f"\nFalta a pasta '{OUTROS}' com fotos. Sem ela o modelo é obrigado "
              "a escolher uma das fases treinadas para qualquer foto — até a da "
              "nota fiscal — e o app preenche a fase errada. Ponha ali fotos que "
              "não são de fase nenhuma e as das fases que você não vai treinar.")
        return False
    fora = [r for r in ROTULOS if r not in com_fotos]
    if fora:
        print(f"\n! Fases fora do treino: {', '.join(fora)}. Ponha fotos delas em "
              f"'{OUTROS}': senão o modelo chama essas fotos de uma das fases "
              "treinadas.")
    if min(com_fotos.values()) < MINIMO_POR_FASE // 3:
        print("\nAlguma classe tem fotos de menos para o modelo aprender alguma coisa. "
              "Junte mais fotos dela ou tire a pasta.")
        return False
    maior, menor = max(com_fotos.values()), min(com_fotos.values())
    if maior > 3 * menor:
        print(f"\n! Classes desequilibradas ({maior} contra {menor}). O treino "
              "compensa com peso por classe, mas fotos a mais nas pequenas "
              "ajudam mais.")
    return True


def pesos_por_classe(contagem: dict[str, int]) -> dict[int, float]:
    """Classe com menos fotos pesa mais no treino, para o modelo não chutar
    sempre a fase mais fotografada. O índice segue a ordem alfabética das
    pastas, que é a que o Model Maker usa."""
    nomes = sorted(contagem)
    total = sum(contagem.values())
    return {
        i: (total / (len(nomes) * contagem[nome])) if contagem[nome] else 0.0
        for i, nome in enumerate(nomes)
    }


def treinar(args: argparse.Namespace, dataset: Path, contagem: dict[str, int],
            dataset_teste: Path | None) -> None:
    # Importado só aqui: carrega o TensorFlow inteiro, e o --verificar não
    # precisa dele.
    from mediapipe_model_maker import image_classifier, quantization

    random.seed(args.semente)
    try:
        import tensorflow as tf

        tf.random.set_seed(args.semente)
    except ImportError:
        pass

    dados = image_classifier.Dataset.from_folder(str(dataset))
    if dataset_teste is not None:
        # Fotos de outra obra: mede se o modelo aprendeu a fase, e não o
        # canteiro onde as fotos de treino foram tiradas.
        teste = image_classifier.Dataset.from_folder(str(dataset_teste))
        treino_e_validacao = dados
    else:
        treino_e_validacao, teste = dados.split(1 - args.fracao_teste)
    treino, validacao = treino_e_validacao.split(1 - args.fracao_validacao)
    print(f"\nTreino: {treino.size} fotos · validação: {validacao.size} · "
          f"teste: {teste.size}")

    saida = Path(args.saida).resolve()
    # O Model Maker grava um checkpoint por época em export_dir/checkpoint/ e,
    # no create(), retoma o último que achar lá. Com o --saida de um treino
    # anterior (o /content/saida fixo do Colab), outro número de classes
    # quebra o treino e as mesmas classes partem em silêncio dos pesos
    # antigos — e o "teste" passa a ter fotos que o treino anterior viu. Por
    # isso o treino roda numa pasta nova e só o resultado vai para --saida.
    exportacao = Path(tempfile.mkdtemp(prefix="obrafacil_treino_"))
    try:
        _treinar_e_exportar(args, image_classifier, quantization, treino,
                            validacao, teste, contagem, exportacao)
        saida.mkdir(parents=True, exist_ok=True)
        for nome in (NOME_DO_ARQUIVO, "labels.txt"):
            shutil.copy2(exportacao / nome, saida / nome)
    finally:
        shutil.rmtree(exportacao, ignore_errors=True)
    arquivo = saida / NOME_DO_ARQUIVO
    print(f"\nModelo exportado: {arquivo} ({arquivo.stat().st_size / 1e6:.1f} MB)")
    print("Próximo passo: copie para obra_facil/assets/modelos/fases_obra.tflite "
          "e gere o app de novo (docs/ia/treinar-modelo.md).")


def _treinar_e_exportar(args, image_classifier, quantization, treino, validacao,
                        teste, contagem: dict[str, int], exportacao: Path) -> None:
    hparams = image_classifier.HParams(
        epochs=args.epocas,
        batch_size=args.lote,
        learning_rate=args.taxa,
        do_fine_tuning=args.ajuste_fino,
        class_weights=pesos_por_classe(contagem),
        export_dir=str(exportacao),
    )
    opcoes = image_classifier.ImageClassifierOptions(
        supported_model=getattr(image_classifier.SupportedModels, MODELOS[args.modelo]),
        hparams=hparams,
    )
    modelo = image_classifier.ImageClassifier.create(
        train_data=treino, validation_data=validacao, options=opcoes)

    resultado = modelo.evaluate(teste)
    nomes = getattr(getattr(modelo, "_model", None), "metrics_names", None)
    print("\nResultado no conjunto de teste (fotos que o treino não viu):")
    if nomes and len(nomes) == len(resultado):
        for nome, valor in zip(nomes, resultado):
            if nome in ("loss", "accuracy"):
                print(f"  {nome}: {valor:.3f}")
    else:
        print(f"  perda: {resultado[0]:.3f} · acurácia: {resultado[1]:.3f}")

    # Quantização dinâmica: pesos em 8 bits, entrada e saída em float — o
    # arquivo fica uns 4x menor e continua no formato que o ML Kit aceita.
    config = quantization.QuantizationConfig.for_dynamic() if args.quantizar else None
    modelo.export_model(NOME_DO_ARQUIVO, quantization_config=config)
    modelo.export_labels(str(exportacao))


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Treina o modelo próprio de fases da obra (ObraFácil).")
    parser.add_argument("--dados", required=True,
                        help="pasta com uma subpasta de fotos por fase")
    parser.add_argument("--dados-teste",
                        help="pasta de teste separada, no mesmo formato "
                             "(de preferência fotos de outra obra)")
    parser.add_argument("--saida", default="saida",
                        help="onde gravar o .tflite (padrão: saida/)")
    parser.add_argument("--modelo", choices=sorted(MODELOS), default="efficientnet_lite0",
                        help="modelo base (padrão: efficientnet_lite0)")
    parser.add_argument("--epocas", type=int, default=15)
    parser.add_argument("--lote", type=int, default=16, help="fotos por passo de treino")
    parser.add_argument("--taxa", type=float, default=0.001, help="taxa de aprendizado")
    parser.add_argument("--ajuste-fino", action="store_true",
                        help="treina também o modelo base (mais lento; ajuda "
                             "com 300+ fotos por fase)")
    parser.add_argument("--fracao-teste", type=float, default=0.1,
                        help="parte das fotos separada para o teste final")
    parser.add_argument("--fracao-validacao", type=float, default=0.15,
                        help="parte do treino usada para validar cada época")
    parser.add_argument("--quantizar", action="store_true",
                        help="exporta com pesos em 8 bits (arquivo ~4x menor)")
    parser.add_argument("--semente", type=int, default=42,
                        help="semente aleatória, para o treino ser repetível")
    parser.add_argument("--verificar", action="store_true",
                        help="só confere as pastas e monta o dataset, sem treinar")
    args = parser.parse_args(argv)

    trabalho = Path(tempfile.mkdtemp(prefix="obrafacil_dataset_"))
    try:
        print(f"Montando o dataset a partir de {args.dados}…")
        contagem, resumos_do_treino = montar_dataset(Path(args.dados), trabalho / "treino")
        if not conferir(contagem):
            sys.exit(1)
        # Pasta vazia viraria uma classe sem foto nenhuma, que o modelo
        # nunca acerta e que ainda assim ocupa uma saída dele.
        for rotulo in [r for r, n in contagem.items() if n == 0]:
            (trabalho / "treino" / rotulo).rmdir()
            del contagem[rotulo]

        dataset_teste = None
        if args.dados_teste:
            print(f"\nMontando o teste a partir de {args.dados_teste}…")
            dataset_teste = trabalho / "teste"
            contagem_teste, _ = montar_dataset(
                Path(args.dados_teste), dataset_teste, classes=sorted(contagem),
                do_treino=resumos_do_treino)
            print("Fotos de teste por classe: " + ", ".join(
                f"{r}={n}" for r, n in sorted(contagem_teste.items())))
            if sum(contagem_teste.values()) == 0:
                sys.exit("O conjunto de teste ficou vazio: use fotos que não "
                         "estejam na pasta de treino.")

        if args.verificar:
            try:
                from mediapipe_model_maker import image_classifier

                dados = image_classifier.Dataset.from_folder(str(trabalho / "treino"))
                print(f"\nDataset montado: {dados.size} fotos, classes "
                      f"{', '.join(dados.label_names)}.")
            except Exception as erro:  # noqa: BLE001 — qualquer falha de import
                print(f"\n! mediapipe-model-maker não carregou ({erro.__class__.__name__}): "
                      "as pastas estão ok, mas o treino não vai rodar aqui.")
            print("Verificação concluída — nada foi treinado.")
            return

        treinar(args, trabalho / "treino", contagem, dataset_teste)
    finally:
        shutil.rmtree(trabalho, ignore_errors=True)


if __name__ == "__main__":
    os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")
    main()
