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
- ✅ **Lançamento por voz** → transcrição automática da fala
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

## 🤖 A inovação: 6 IAs embarcadas (on-device)

O diferencial central do ObraFácil é rodar inteligência **dentro do próprio celular**, sem depender de servidor pago nem de internet no canteiro:

| # | Módulo | Tecnologia | O que faz |
|---|--------|-----------|-----------|
| 1 | Reconhecimento de material | **TensorFlow Lite** | Identifica o material pela câmera em tempo real |
| 2 | OCR de notas fiscais | **Google ML Kit** | Lê a nota fiscal offline em até 4 passes de imagem (realce, binarização Otsu, rotação) e extrai fornecedor, CNPJ validado, data de emissão, total e itens |
| 2b | Lançamento por voz | **Speech-to-Text + parser pt-BR** | Entende a frase falada inteira: valor (inclusive por extenso, gíria e "cada"), fornecedor, data, materiais e categoria |
| 3 | Previsão de estouro | Modelo de **regressão** | Antecipa quando o orçamento vai estourar |
| 4 | Progresso por foto | Análise comparativa de imagens | Estima o avanço real da obra a partir de fotos |
| 5 | Diário de obra por voz | **Speech-to-Text + parser pt-BR** | Transforma o relato falado do dia em clima, tamanho da equipe, fase e data |
| 6 | Leitura da foto do canteiro | **Google ML Kit** | Reconhece a cena da obra e sugere fase, material aparente, clima e um rascunho do registro do dia |

---

## 🛠️ Tecnologias

| Camada | Stack |
|--------|-------|
| App | Flutter (Android first) |
| Estado / Navegação | Provider, go_router |
| Nuvem | Firebase (Auth, Firestore, Storage, Messaging) |
| Banco local / offline | Drift (SQLite) |
| IA on-device | TensorFlow Lite, Google ML Kit |
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
