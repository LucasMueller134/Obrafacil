# ObraFácil 🏗️

App de gestão inteligente de obras para construção civil.

---

## 📋 Funcionalidades

- ✅ Login com perfis (Dono / Mestre de obras)
- ✅ Cadastro e listagem de obras
- ✅ Lançamentos de custos por categoria
- ✅ **Foto da nota fiscal → IA preenche automaticamente (Claude API)**
- ✅ **Áudio falado → IA transcreve e preenche (Whisper + Claude)**
- ✅ Gráficos de gastos por categoria e por semana
- ✅ Relatório semanal gerado por IA
- ✅ Controle de estoque com alertas de baixo estoque
- ✅ Diário de obra (registro diário do que foi feito)
- ✅ Cronograma por fases com % de conclusão
- ✅ Galeria de fotos com linha do tempo
- ✅ Gestão de fornecedores
- ✅ Firebase (sync em tempo real)
- ✅ Android first

---

## 🚀 Passo a Passo de Configuração

### 1. Criar projeto no Firebase

1. Acesse https://console.firebase.google.com
2. Clique em **"Adicionar projeto"**
3. Nome: `obra-facil` → avançar
4. Ative o Google Analytics se quiser → **Criar projeto**

### 2. Configurar Android no Firebase

1. No painel do Firebase, clique em **"Adicionar app" → Android**
2. Nome do pacote: `com.obrafacil.obra_facil`
3. Apelido: `ObraFácil Android`
4. Clique em **"Registrar app"**
5. **Baixe o arquivo `google-services.json`**
6. Copie o `google-services.json` para: `android/app/google-services.json`

### 3. Ativar serviços no Firebase

No console Firebase, ative:

**Authentication:**
- Menu lateral → Authentication → "Começar"
- Aba "Sign-in method" → Ativar **E-mail/senha**

**Firestore:**
- Menu lateral → Firestore Database → "Criar banco de dados"
- Escolha **Modo de teste** por agora → próximo → criar
- Região: `us-east1` ou a mais próxima

**Storage:**
- Menu lateral → Storage → "Começar"
- Modo de teste → próximo → criar

### 4. Instalar FlutterFire CLI e configurar

```bash
# Instalar FlutterFire CLI
dart pub global activate flutterfire_cli

# Na pasta do projeto, executar:
flutterfire configure
```

Selecione o projeto `obra-facil` e marque **Android**.

Isso vai gerar/atualizar o arquivo `lib/firebase_options.dart` automaticamente.

### 5. Configurar as chaves de IA

Abra `lib/constants/app_constants.dart` e substitua:

```dart
static const String claudeApiKey = 'SUA_CLAUDE_API_KEY_AQUI';
static const String openAiApiKey = 'SUA_OPENAI_API_KEY_AQUI';
```

**Como obter as chaves:**

- **Claude API:** https://console.anthropic.com → API Keys → Create Key
- **OpenAI (Whisper):** https://platform.openai.com → API Keys → Create new secret key

### 6. Instalar dependências e rodar

```bash
# Instalar pacotes
flutter pub get

# Verificar ambiente
flutter doctor

# Rodar no dispositivo/emulador Android
flutter run
```

---

## 📁 Estrutura do Projeto

```
lib/
├── constants/
│   ├── app_constants.dart    ← Cores, textos, API keys
│   └── app_theme.dart        ← Tema visual do app
├── models/
│   ├── usuario_model.dart
│   ├── obra_model.dart
│   ├── lancamento_model.dart
│   └── models.dart           ← Fornecedor, Estoque, Diário, Cronograma, Galeria
├── providers/
│   └── app_provider.dart     ← Estado global do app
├── services/
│   ├── auth_service.dart     ← Firebase Auth
│   ├── firebase_service.dart ← Firestore + Storage
│   └── ia_service.dart       ← Claude API + Whisper
├── screens/
│   ├── auth/                 ← Login e Cadastro
│   ├── obras/                ← Lista e detalhe de obras
│   ├── lancamentos/          ← Lista e novo lançamento
│   ├── estoque/              ← Controle de estoque
│   ├── diario/               ← Diário de obra
│   ├── cronograma/           ← Cronograma por fases
│   ├── galeria/              ← Fotos da obra
│   ├── fornecedores/         ← Gestão de fornecedores
│   └── relatorios/           ← Relatórios e gráficos
└── main.dart
```

---

## ⚠️ Regras do Firestore (Segurança)

No console Firebase → Firestore → Regras, cole:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

E no Storage → Regras:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## 🎨 Paleta de Cores

| Cor | Hex | Uso |
|-----|-----|-----|
| Laranja | `#F97316` | Cor principal, botões |
| Azul escuro | `#1E293B` | AppBar, secundária |
| Amarelo | `#FCD34D` | Accent / destaque |
| Verde | `#22C55E` | Sucesso |
| Vermelho | `#EF4444` | Erro / alerta |
| Amarelo âmbar | `#F59E0B` | Aviso |

---

## 📱 Próximos passos sugeridos

- [ ] Modo offline completo com sincronização (Drift + sync)
- [ ] Exportar relatório em PDF
- [ ] Notificações push (Firebase Messaging)
- [ ] Orçamento baseado em histórico de obras
- [ ] Comparativo entre obras

---

Desenvolvido com Flutter + Firebase + Claude AI + Whisper 🚀
