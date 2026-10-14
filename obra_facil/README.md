# ObraFácil — app Flutter

App Android de gestão de obras (custos, equipe, estoque, diário e
cronograma) com IA que roda **no próprio celular, sem internet e sem
custo**. A visão geral do projeto está no [README da raiz](../README.md).

- **Como configurar e rodar:** [SETUP.md](SETUP.md) (Flutter, Firebase,
  regras do Firestore, roteiro de demonstração).
- **Como as IAs funcionam e quanto acertam:**
  [docs/ia/RELATORIO-IA.md](../docs/ia/RELATORIO-IA.md).
- **Treinar o modelo próprio de fases da obra:**
  [docs/ia/treinar-modelo.md](../docs/ia/treinar-modelo.md).

## IA no aparelho

| Módulo | Onde | Tecnologia |
|---|---|---|
| Nota fiscal por foto | `lib/services/ia/ocr_nota_service.dart` | ML Kit Text Recognition + leitor de QR/código de barras (chave de acesso) + regras para notas brasileiras |
| Lançamento por voz | `lib/services/ia/voz_service.dart` | Reconhecedor de voz do Android em modo offline + interpretação da frase em pt-BR |
| Diário por voz | `lib/services/ia/diario_voz_service.dart` | Mesmo reconhecedor + clima, equipe, fase e data |
| Foto do canteiro | `lib/services/ia/diario_foto_service.dart` | Classificador do ML Kit + análise de cor + modelo próprio opcional |
| Material pela câmera | `lib/services/ia/material_vision_service.dart` | Classificador do ML Kit + texto da embalagem |
| Mudança visual entre fotos | `lib/services/ia/progresso_foto_service.dart` | Comparação de imagens (luz equalizada + bordas) |
| Previsões e relatório | `lib/services/ia/previsao_*.dart`, `relatorio_semanal_service.dart`, `perguntas_obra_service.dart` | Regressão e regras em Dart puro |

**Nenhuma chave de API.** O app não usa serviço de IA na nuvem: a única
exceção é opcional e explícita — quando falta o pacote de voz offline, a
pessoa pode escolher o reconhecimento online do Google para uma gravação, e
a tela avisa que o áudio vai para o Google. O único
arquivo de configuração externa é `lib/firebase_options.dart`, gerado pelo
`flutterfire configure`; a chave que aparece nele identifica o projeto
Firebase e não é segredo — quem protege os dados são as regras de
`firestore.rules`.

## Testes e avaliação

```bash
flutter test                                    # testes unitários
flutter test test/avaliacao/avaliacao_ia_test.dart   # acerto das IAs por campo
```

O conjunto de avaliação e como acrescentar casos reais do canteiro estão em
[test/avaliacao/LEIA-ME.md](test/avaliacao/LEIA-ME.md).
