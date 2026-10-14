# Treinar o modelo próprio de fases da obra

A leitura da foto do diário usa o classificador de imagens do ML Kit, que
roda no celular e sem internet. Só que ele foi treinado com fotos do dia a
dia: tem uns 400 rótulos genéricos em inglês ("Wood", "Roof", "Wall") e
nenhum de obra — "formwork", "rebar" e "masonry" quase nunca aparecem. O app
compensa com regras (a madeira junto de solo é baldrame, o vermelho debaixo
do céu é telha...), mas regra por cima de rótulo genérico tem limite.

Um **modelo próprio**, treinado com as fotos das suas obras, conhece as fases
de verdade. Ele continua rodando **no aparelho, sem internet e sem custo**: o
treino é feito uma vez (no Google Colab, de graça, ou num computador), e o
arquivo `.tflite` vai dentro do app.

> O modelo próprio é opcional. Sem ele o app funciona como sempre, só com o
> modelo base. Se o arquivo faltar ou não carregar, nada quebra.

## Como o app usa o modelo

- O arquivo fica em `obra_facil/assets/modelos/fases_obra.tflite`.
- Na primeira foto do diário o app copia o modelo para a pasta do aparelho
  (o ML Kit só abre modelo por caminho de arquivo) e passa a rodá-lo junto do
  modelo base, pelo `LocalLabelerOptions` do `google_mlkit_image_labeling`.
- Os rótulos do modelo próprio são as **fases sem acento**: `fundacao`,
  `estrutura`, `alvenaria`, `cobertura`, `instalacoes_eletricas`,
  `instalacoes_hidraulicas`, `reboco_e_contrapiso`, `revestimentos`,
  `pintura`, `acabamento`. Eles entram como evidência forte, pesando pela
  confiança: a partir de 50% bastam para preencher a fase quando nada mais
  na foto aponta outra; perto de 100% valem o mesmo que duas evidências
  fortes do modelo base juntas. Abaixo de 50% só ajudam a desempatar.
- Em **"Ver o que a IA viu na foto"** eles aparecem como
  `Modelo da obra: Fundação 82%`. Se nunca aparecer nada assim, o modelo não
  carregou (o motivo fica no log: `Modelo próprio de fases não carregou`).

## 1. Quantas fotos por fase

| | Fotos por fase |
|---|---|
| Mínimo (o script recusa abaixo de 10 e avisa abaixo de 30) | 30 |
| Recomendado | 100 a 200 |
| Com `--ajuste-fino` | 300 ou mais |

- **Não precisa treinar as 10 fases.** Treine só as que você tem fotos; o
  modelo só opina sobre as fases que aprendeu, e as outras continuam com o
  modelo base.
- **Equilibre as fases.** Se uma tem 300 fotos e outra 40, o modelo tende a
  chutar a maior. O script compensa com peso por classe e avisa quando a
  diferença passa de 3 para 1, mas fotos a mais na fase pequena ajudam mais.
- **Use fotos de pelo menos 3 obras diferentes.** Com uma obra só, o modelo
  aprende a obra (o muro do vizinho, a cor da terra), não a fase.
- **Crie também a pasta `outros`** (50 a 100 fotos): nota fiscal, selfie,
  material solto, almoço da equipe — tudo que vai parar no diário e não é
  fase nenhuma. Sem ela o modelo é obrigado a escolher uma fase para tudo.
  O app ignora esse rótulo.

## 2. Como fotografar

O modelo aprende com o tipo de foto que recebe — fotografe como se fosse
registrar o dia no diário:

- **Foto aberta do canteiro**, não detalhe. Um palmo de parede não diz se é
  alvenaria ou reboco; o pano inteiro diz.
- **Varie** horário (manhã, meio-dia, fim de tarde), tempo (sol, nublado,
  chuva), ângulo (de frente, de lado, de cima da laje) e distância.
- **Uma fase por foto.** Se a foto mostra duas etapas (alvenaria subindo e a
  cobertura começando), ponha na fase que estava sendo executada naquele
  dia — a que o encarregado registraria — ou deixe a foto de fora.
- **Nada de rajada.** Dez fotos quase iguais tiradas em sequência valem por
  uma e, pior, uma cai no treino e a outra no teste, inflando a nota. Prefira
  poucas fotos diferentes a muitas parecidas.
- Formato: JPEG ou PNG. Fotos HEIC do iPhone precisam ser convertidas (o
  script avisa quais ignorou). O tamanho não importa: o modelo reduz tudo
  para 224×224.

## 3. Organizar as pastas

Uma pasta por fase; o nome da pasta é a fase. Acento, maiúscula e espaço
não importam ("Reboco e contrapiso" vira `reboco_e_contrapiso`). Dentro de
cada fase pode haver subpastas, por obra:

```
fotos/
  fundacao/
    obra_centro/   IMG_0012.jpg ...
    obra_bairro/   ...
  estrutura/
  alvenaria/
  Reboco e contrapiso/
  outros/
```

Pasta com outro nome é ignorada (o script avisa). Foto repetida — o mesmo
arquivo em duas pastas — entra uma vez só.

## 4. Conferir antes de treinar

```bash
python ferramentas/treinar_modelo/treinar.py --dados fotos/ --verificar
```

Mostra quantas fotos há por fase, avisa o que está pouco ou desequilibrado e
monta o dataset — sem treinar nada. Rode até não sobrar aviso importante.

## 5. Treinar no Google Colab

O Colab é gratuito e já tem acesso ao TF Hub, de onde o treino baixa o
modelo base (MobileNet/EfficientNet). A internet só é usada aqui, no treino:
o app continua 100% no aparelho.

1. Compacte a pasta `fotos/` num `fotos.zip` e envie para o seu Google Drive
   (por exemplo em `MeuDrive/obrafacil/fotos.zip`).
2. Abra <https://colab.research.google.com>, crie um notebook e, em
   **Ambiente de execução → Alterar o tipo de ambiente**, escolha **GPU T4**
   (treina em minutos em vez de dezenas de minutos).
3. Rode, uma célula por vez:

```python
# O script do repositório e o Model Maker (versão em requirements.txt,
# conferida com Python 3.11)
!python --version
!git clone -q --depth 1 https://github.com/LucasMueller134/Obrafacil.git /content/Obrafacil
!pip install -q -r /content/Obrafacil/ferramentas/treinar_modelo/requirements.txt
```

```python
# Fotos do Drive
from google.colab import drive
drive.mount('/content/drive')
!unzip -q -o /content/drive/MyDrive/obrafacil/fotos.zip -d /content/fotos
```

```python
# Conferir e treinar
!python /content/Obrafacil/ferramentas/treinar_modelo/treinar.py --dados /content/fotos --verificar
!python /content/Obrafacil/ferramentas/treinar_modelo/treinar.py --dados /content/fotos --saida /content/saida --quantizar
```

```python
# Baixar o modelo
from google.colab import files
files.download('/content/saida/fases_obra.tflite')
```

Se o `pip install` falhar, quase sempre é a versão do Python do Colab mais
nova que a suportada pelo Model Maker: confira o `python --version` e, se
for o caso, troque o ambiente de execução para uma versão anterior. Também
dá para treinar num computador com Python 3.10 ou 3.11:
`pip install -r ferramentas/treinar_modelo/requirements.txt` e os mesmos
comandos.

### Opções do script

| Opção | Para quê |
|---|---|
| `--dados-teste outra_obra/` | Mede com fotos de outra obra (mesmo formato de pastas). É a medida mais honesta: diz se o modelo aprendeu a fase ou a obra. Fotos que já estão no treino são tiradas do teste. |
| `--quantizar` | Pesos em 8 bits: arquivo uns 4× menor (o padrão fica na casa de 10 a 15 MB). |
| `--modelo mobilenet_v2` | Modelo base menor e mais rápido, um pouco menos preciso. O padrão é `efficientnet_lite0`. |
| `--epocas 15` | Passadas pelas fotos. Se a acurácia da validação ainda sobe na última época, aumente. |
| `--ajuste-fino` | Treina também o modelo base. Só compensa com 300+ fotos por fase. |
| `--semente 42` | Repete o mesmo sorteio de treino/teste, para comparar duas versões. |

## 6. Colocar o modelo no app

1. Copie o arquivo para `obra_facil/assets/modelos/fases_obra.tflite` (o
   nome tem de ser exatamente esse). A pasta já está declarada no
   `pubspec.yaml`.
2. Gere o app de novo (`flutter build apk` ou o CI). Atualizações seguintes
   do modelo são copiadas de novo para o aparelho automaticamente: o app
   compara o tamanho do arquivo.
3. No aparelho, tire uma foto no diário e abra **"Ver o que a IA viu na
   foto"**: deve aparecer uma linha `Modelo da obra: <fase>`.

> O formato exportado pelo Model Maker traz os metadados (rótulos e
> normalização) que o ML Kit exige de modelo próprio. Mesmo assim, confira
> no passo 3 na primeira vez: se o ML Kit recusar o arquivo, o app segue só
> com o modelo base e registra o motivo no log.

## 7. Medir se melhorou

1. **No treino:** o script imprime a acurácia no conjunto de teste (fotos
   que o treino não viu). Abaixo de 70%, junte mais fotos e mais variedade
   — e veja quais fases se confundem (reboco × pintura é o clássico).
2. **No conjunto de avaliação do app** (`obra_facil/test/avaliacao/`):
   copie casos reais do canteiro para `casos/foto_diario.json` com a
   origem `"real"`, incluindo nos `rotulos` o que o modelo próprio devolveu
   (por exemplo `["fundacao", 0.82]`, como aparece em "Ver o que a IA viu").
   Depois compare antes e depois:

   ```bash
   cd obra_facil
   AVALIACAO_SALVAR=sem-modelo flutter test test/avaliacao/avaliacao_ia_test.dart
   # ... inclua os rótulos do modelo nos casos ...
   AVALIACAO_SALVAR=com-modelo flutter test test/avaliacao/avaliacao_ia_test.dart
   ```

   O que interessa é o campo `fase`: **acerto** sobe e **errado** (o pior
   caso, a fase preenchida errada) não pode subir.
3. **No uso:** quando o app errar a fase, guarde a foto na pasta da fase
   certa. É assim que o próximo treino aprende com o seu canteiro.

## Problemas comuns

| Sintoma | Causa provável |
|---|---|
| "É preciso de pelo menos duas classes com fotos" | Os nomes das pastas não batem com as fases (o script lista os aceitos). |
| Acurácia alta no treino e baixa em `--dados-teste` | Fotos de uma obra só, ou rajadas quase iguais: o modelo decorou a obra. |
| Sempre a mesma fase | Classes desequilibradas, ou falta a pasta `outros`. |
| "Modelo da obra" nunca aparece no app | Arquivo com outro nome ou fora de `assets/modelos/`, ou o ML Kit recusou o modelo — veja o log do aparelho. |
| Erro de download no treino | Sem acesso ao TF Hub (rede bloqueada): treine no Colab. |
