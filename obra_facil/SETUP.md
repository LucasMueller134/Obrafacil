# 🛠️ ObraFácil — Guia de configuração e execução

Passo a passo para rodar o projeto do zero numa máquina nova.

## Pré-requisitos

| Ferramenta | Versão | Verificar |
|---|---|---|
| Flutter SDK | 3.24+ (canal stable) | `flutter --version` |
| Android Studio + SDK | API 34+ | `flutter doctor` |
| Java | 17 (vem com o Android Studio) | `flutter doctor -v` |
| Conta Google | — | para o Firebase |

Rode `flutter doctor` e resolva qualquer ✗ antes de continuar.

## 1. Dependências

```bash
flutter pub get
```

## 2. Firebase (obrigatório — 1x por projeto)

O app usa **Firebase Auth** (login) e **Cloud Firestore** (dados + offline).

1. Crie um projeto em <https://console.firebase.google.com> (plano Spark/gratuito basta —
   o protótipo não usa Firebase Storage; fotos são comprimidas e salvas no Firestore).
2. No console: **Authentication → Sign-in method → E-mail/senha → Ativar**.
3. No console: **Firestore Database → Criar banco de dados** (modo produção,
   região `southamerica-east1`).
4. Publique as regras de segurança: copie o conteúdo de [`firestore.rules`](firestore.rules)
   em **Firestore → Regras → Publicar**.
5. Conecte o app ao projeto (gera o `lib/firebase_options.dart` real):

```bash
dart pub global activate flutterfire_cli
flutterfire configure
# selecione o projeto criado e a plataforma Android
```

> Enquanto o `flutterfire configure` não for executado, o app abre numa tela
> de "configuração pendente" com essas instruções — ele não quebra.

## 3. Rodar no celular

```bash
flutter run
```

Celular físico com **depuração USB** ativada é o ideal — os módulos de IA
(câmera, OCR, voz) não funcionam bem no emulador.

## 4. Roteiro de demonstração (pitch/banca)

1. Crie uma conta **Dono/Gestor** e uma obra (o cronograma padrão é gerado sozinho).
2. Copie o **código de convite** no dashboard da obra.
3. Em outro aparelho (ou após logout), crie uma conta **Mestre de obras** e entre com o código.
4. Como mestre: lance um gasto **tirando foto de uma nota fiscal** (OCR preenche) e outro **por voz**.
5. Como dono: **aprove/rejeite** os lançamentos pendentes e veja os gráficos atualizarem.
6. Abra o **Relatório semanal (IA)** e a **previsão de estouro** no dashboard.
7. Modo offline: ative o modo avião, lance um gasto, desative — ele sincroniza sozinho.

## Arquitetura (resumo)

```
lib/
├── constants/   # cores (tema escuro "Canteiro Premium"), domínio
├── models/      # entidades + toMap/fromMap (Firestore)
├── services/
│   ├── auth_service.dart        # Firebase Auth
│   ├── firestore_service.dart   # CRUD + streams + offline
│   ├── imagem_service.dart      # compressão de fotos (base64)
│   └── ia/                      # IA on-device (ver docs/ia/RELATORIO-IA.md)
│       ├── ocr_nota_service.dart          # nota fiscal: ML Kit OCR + regras de nota BR
│       ├── linhas_ocr.dart, chave_acesso.dart # colunas pela posição; chave da NFC-e/NF-e
│       ├── voz_service.dart, valor_falado.dart # lançamento por voz (fala -> campos)
│       ├── diario_voz_service.dart        # diário por voz (clima, equipe, fase)
│       ├── escuta_voz.dart, hipoteses_voz.dart, vocabulario_obra.dart # microfone e ruído
│       ├── diario_foto_service.dart, cores_foto.dart, modelo_fases.dart # foto do canteiro
│       ├── material_vision_service.dart   # material pela foto e pelo texto da embalagem
│       ├── progresso_foto_service.dart    # mudança visual entre duas fotos
│       ├── previsao_*_service.dart        # regressão (orçamento e estoque)
│       └── relatorio_semanal_service.dart, perguntas_obra_service.dart # texto por regras
├── providers/   # AuthProvider (estado global de sessão)
├── router/      # go_router + guarda de autenticação
├── screens/     # telas por módulo
├── widgets/     # componentes reutilizáveis (gráficos, cards…)
└── utils/       # formatação pt-BR e validação
```

**Decisões de projeto relevantes para a banca:**

- **Offline-first** via persistência nativa do Firestore (cache local +
  fila de escrita), em vez de banco local próprio + sincronização manual —
  menos código, menos bugs de sync, mesmo resultado prático.
- **Fotos em base64 no Firestore** (comprimidas a ~900px/70%) em vez de
  Firebase Storage, que passou a exigir plano pago em projetos novos.
  O widget `ImagemObra` também aceita URLs http, então a migração para
  Storage é transparente.
- **IA 100% on-device**: ML Kit (modelos TFLite embarcados) para OCR,
  código de barras e visão; reconhecedor de voz do Android em modo
  offline; regressão e geração de relatório em Dart puro. Por padrão
  nada sai do aparelho e tudo funciona sem internet. Para a voz offline, o
  celular precisa do pacote de reconhecimento de português baixado; sem
  ele, o app explica como baixar e oferece o reconhecimento online do
  Google só para aquela gravação — e só se a pessoa escolher (a tela avisa
  que, nesse caso, o áudio vai para o Google). Acerto de cada IA, medido antes e depois:
  [docs/ia/RELATORIO-IA.md](../docs/ia/RELATORIO-IA.md).
- **Fluxo de aprovação**: lançamento de mestre nasce `pendente`; do dono
  nasce `aprovado`. Só entra nos gráficos e na previsão o que foi aprovado.
