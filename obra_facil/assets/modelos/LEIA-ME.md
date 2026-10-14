# Modelo próprio de fases da obra (opcional)

Coloque aqui o arquivo **`fases_obra.tflite`** gerado pelo treino
(`ferramentas/treinar_modelo/treinar.py`, na raiz do repositório). Com ele, a
leitura da foto do diário passa a usar também um classificador treinado com
as fotos das suas obras; sem ele, o app usa só o modelo base do ML Kit — nada
quebra.

O passo a passo (quantas fotos, como fotografar, treino no Google Colab e
como medir o resultado) está em `docs/ia/treinar-modelo.md`.

Este arquivo existe para a pasta não ficar vazia: o `pubspec.yaml` declara
`assets/modelos/` e o build falha se a pasta não existir.
