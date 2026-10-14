# 🏗️ ObraFácil

> **Gestão inteligente de obras na palma da mão.**
> Aplicativo Android para controle de custos, equipe e progresso em obras de construção civil — com IA embarcada que funciona offline.

<p>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-Android-02569B?logo=flutter&logoColor=white">
  <img alt="Firebase" src="https://img.shields.io/badge/Firebase-Cloud-FFCA28?logo=firebase&logoColor=black">
  <img alt="IA on-device" src="https://img.shields.io/badge/IA-on--device-F97316">
  <img alt="Status" src="https://img.shields.io/badge/status-prot%C3%B3tipo%20acad%C3%AAmico-FBBF24">
</p>

---

## 📋 Sobre o projeto

O **ObraFácil** é um projeto de aplicação desenvolvido individualmente no curso de **Engenharia de Software** do **Centro Universitário Católica de Santa Catarina (CatólicaSC)**.

Ele nasceu de um problema real e comum nas obras de pequeno e médio porte: a gestão feita "no caderninho", no grupo de WhatsApp e na memória do dono. Esse modelo informal faz o construtor **perder o controle dos custos**, **não enxergar o gasto real por obra** e **não ter registro auditável** do que acontece no canteiro.

O ObraFácil resolve isso colocando o controle completo da obra no celular — de forma simples, móvel e com **inteligência artificial embarcada que roda no próprio aparelho, mesmo sem internet**.

🎥 **Vídeo de apresentação (Pitch):** [assista aqui](https://youtu.be/Z8BTWrMxLTY)

---

## 🎯 O problema

| Dor | Impacto |
|-----|---------|
| Custos anotados em papel | O estouro do orçamento só é percebido no fim da obra |
| Sem visão do gasto por categoria | Impossível comparar obras ou planejar compras |
| Comunicação solta (WhatsApp / boca a boca) | Nada fica registrado nem auditável |

Estima-se que **mais de 30% do custo de uma obra** pode se perder com desperdício e retrabalho mal controlados. Os ERPs de construção existentes são caros e voltados para grandes empresas — deixando o pequeno construtor sem ferramenta adequada.

---

## 💡 A solução

Um aplicativo **Android** com **três perfis de acesso** e **fluxo de aprovação**:

- **👷 Mestre de obras** — registra gastos, uso de material e diário da obra. Tira foto da nota e o app preenche sozinho. Não compra: apenas informa o que foi usado.
- **🧑‍💼 Dono / Gestor** — aprova ou rejeita cada lançamento, acompanha gráficos de custo e recebe relatório semanal gerado por IA.
- **🏠 Cliente** — quem contratou a obra. Entra com um código de acompanhamento e vê progresso, fases, diário e fotos, além de poder perguntar à IA sobre o andamento. **Nenhum dado financeiro** chega até ele: as regras do Firestore recusam a leitura dos lançamentos para este perfil, então não é só a tela que esconde.

---

## ✨ Funcionalidades

- ✅ Cadastro e gestão de múltiplas obras
- ✅ Lançamento de custos por categoria (mão de obra, material, equipamento)
- ✅ **Nota fiscal por foto** → OCR preenche o gasto automaticamente
- ✅ **Lançamento por voz** → a fala vira o lançamento preenchido, sem internet
- ✅ Gráficos de gastos por categoria e por semana
- ✅ Relatório semanal gerado por IA
- ✅ Controle de estoque com alerta de baixo estoque
- ✅ Diário de obra
- ✅ Cronograma por fases com % de conclusão
- ✅ Galeria de fotos com linha do tempo
- ✅ Gestão de fornecedores (cadastro automático)
- ✅ Área do cliente com acompanhamento da obra e assistente sem custos
- ✅ **Confirmação de e-mail** no cadastro (obrigatória para o cliente)
- ✅ **CEP conferido nos Correios** (ViaCEP), preenchendo o endereço da obra
- ✅ Sincronização em tempo real + **modo offline**

---

## 🤖 A inovação: IA embarcada (on-device)

O diferencial central do ObraFácil é rodar inteligência **dentro do próprio celular**, sem depender de servidor pago nem de internet no canteiro. Nenhuma chave de API, nenhum custo por uso.

| # | Módulo | Tecnologia | O que faz |
|---|--------|-----------|-----------|
| 1 | Nota fiscal por foto | **Google ML Kit** (texto + QR/código de barras) | Lê a nota offline, remonta as colunas pela posição do texto e confere CNPJ e data pela chave de acesso da NFC-e/NF-e; extrai fornecedor, CNPJ, data, total e itens |
| 2 | Lançamento por voz | **Reconhecedor do Android (offline) + parser pt-BR** | Entende a frase falada inteira: valor (com ou sem "reais", "2 mil", "a 35 cada"), fornecedor, data, materiais e categoria, mesmo com o ruído do canteiro |
| 3 | Diário de obra por voz | **Reconhecedor do Android (offline) + parser pt-BR** | Transforma o relato do dia em clima, tamanho da equipe, fase e data |
| 4 | Leitura da foto do canteiro | **Google ML Kit** + análise de cor + modelo próprio opcional | Sugere fase, material aparente e clima; só preenche a fase quando a evidência sustenta |
| 5 | Material pela câmera | **Google ML Kit** (imagem + texto da embalagem) | Identifica o material pela foto e pelo que está escrito no saco, lata ou caixa |
| 6 | Mudança visual entre fotos | Comparação de imagens (luz equalizada + bordas) | Mede quanto a cena mudou entre duas fotos do mesmo ponto |
| 7 | Previsão de estouro e de estoque | Regressão em Dart puro | Antecipa quando o orçamento vai estourar e quando o material acaba |
| 8 | Relatório semanal e assistente | Regras em Dart puro | Resume a semana e responde perguntas sobre a obra |

Quanto cada IA acerta — medido num conjunto de 133 casos, antes e depois da revisão — está em [docs/ia/RELATORIO-IA.md](docs/ia/RELATORIO-IA.md).

---

## 🛠️ Tecnologias

| Camada | Stack |
|--------|-------|
| App | Flutter (Android first) |
| Estado / Navegação | Provider, go_router |
| Nuvem | Firebase (Auth, Firestore, Storage, Messaging) |
| Banco local / offline | Drift (SQLite) |
| IA on-device | Google ML Kit (TensorFlow Lite), reconhecedor de voz do Android |
| Gráficos | fl_chart |
| Identidade visual | Tema escuro "Canteiro Premium" (laranja `#F97316`, cinza-cimento `#374151`, amarelo-capacete `#FBBF24`) |

---

## 📁 Estrutura do projeto

```
lib/
├── models/         # Modelos de dados (Obra, Lançamento, Fornecedor...)
├── services/       # Firebase, IA, OCR, sincronização
├── providers/      # Gerência de estado
├── screens/        # Telas (auth, obras, lançamentos, relatórios...)
├── widgets/        # Componentes reutilizáveis
├── utils/          # Funções auxiliares
└── constants/      # Cores, temas e textos
```

---

## 📚 Contexto acadêmico

- **Instituição:** Centro Universitário Católica de Santa Catarina (CatólicaSC)
- **Curso:** Engenharia de Software
- **Entrega:** Portfólio individual — vídeo pitch + README + documento de portfólio

---

## 👤 Autor

**Lucas Mueller**
Engenharia de Software — CatólicaSC

---

<p align="center"><i>Menos caderninho. Mais controle. Inteligência no canteiro.</i></p>
