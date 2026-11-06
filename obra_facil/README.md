# Obra na Mão — app Flutter

App Android de gestão de obras (custos, equipe, estoque, diário,
cronograma, maquete 3D e planta) com IA que roda **no próprio celular, sem
internet e sem custo**. A visão geral do projeto está no
[README da raiz](../README.md).

- **Como configurar e rodar:** [SETUP.md](SETUP.md) (Flutter, Firebase,
  regras do Firestore, roteiro de demonstração).
- **Como as IAs funcionam e quanto acertam:**
  [docs/ia/RELATORIO-IA.md](../docs/ia/RELATORIO-IA.md).
- **Treinar o modelo próprio de fases da obra:**
  [docs/ia/treinar-modelo.md](../docs/ia/treinar-modelo.md).
- **IA da planta (Gemini, opcional, na nuvem):**
  [docs/ia/gemini-planta.md](../docs/ia/gemini-planta.md).
- **Design system Prancheta e capturas das telas:**
  [docs/redesign/design-system.md](../docs/redesign/design-system.md) e
  [docs/redesign/LEIA-ME-capturas.md](../docs/redesign/LEIA-ME-capturas.md).

## IA no aparelho

| Módulo | Onde | Tecnologia |
|---|---|---|
| Nota fiscal por foto | `lib/services/ia/ocr_nota_service.dart` | ML Kit Text Recognition + leitor de QR/código de barras (chave de acesso) + regras para notas brasileiras |
| Lançamento por voz | `lib/services/ia/voz_service.dart` | Reconhecedor de voz do Android em modo offline + interpretação da frase em pt-BR |
| Diário por voz | `lib/services/ia/diario_voz_service.dart` | Mesmo reconhecedor + clima, equipe, fase e data |
| Foto do canteiro | `lib/services/ia/diario_foto_service.dart` | Classificador do ML Kit + análise de cor + modelo próprio opcional |
| Material pela câmera | `lib/services/ia/material_vision_service.dart` | Classificador do ML Kit + texto da embalagem |
| Mudança visual entre fotos | `lib/services/ia/progresso_foto_service.dart` | Comparação de imagens (luz normalizada + bordas) |
| Previsões e relatório | `lib/services/ia/previsao_*.dart`, `relatorio_semanal_service.dart`, `perguntas_obra_service.dart` | Regressão e regras em Dart puro |

**Nenhuma chave de API no app.** As IAs da tabela acima não usam serviço
na nuvem. A única exceção da voz é opcional e explícita: quando falta o
pacote de voz offline, a pessoa pode escolher o reconhecimento online do
Google para uma gravação, e a tela avisa que o áudio vai para o Google.

A leitura da planta e as imagens "como vai ficar" usam o Gemini, mas pelas
Cloud Functions da pasta [`functions/`](../functions): a chave fica no
Secret Manager do Google Cloud e o app só chama a função, com o login do
Firebase (`lib/services/ia/planta_ia_service.dart`). Sem as funções
publicadas, o app avisa e o resto segue funcionando.

O único arquivo de configuração externa é `lib/firebase_options.dart`,
gerado pelo `flutterfire configure`; a chave que aparece nele identifica o
projeto Firebase e não é segredo. Quem protege os dados são as regras de
`firestore.rules` (e `../storage.rules`).

## Maquete 3D

A maquete usa o `flutter_scene` (Flutter GPU). Sem planta, é a casa-padrão
(`assets/3d/maquete.glb`, feita no Blender por
`ferramentas/maquete_3d/`). Com a planta da obra, o app gera a casa no
próprio aparelho (`lib/design/maquete/gerador/`), com as mesmas peças por
fase. Sem Flutter GPU no aparelho, aparece a imagem de reserva ou a planta
desenhada.

## Testes e avaliação

```bash
flutter test                                    # testes de unidade e de tela
flutter test test/avaliacao/avaliacao_ia_test.dart   # acerto das IAs por campo
```

O conjunto de avaliação e como acrescentar casos reais do canteiro estão em
[test/avaliacao/LEIA-ME.md](test/avaliacao/LEIA-ME.md).

As capturas das telas (claro e escuro) são geradas por
`CAPTURAR=depois flutter test test/visual/`; ver
[docs/redesign/LEIA-ME-capturas.md](../docs/redesign/LEIA-ME-capturas.md).
