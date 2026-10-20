part of 'obra_detalhe_screen.dart';

// As partes da central da obra. Tudo aqui é interface: as contas são as
// mesmas das outras telas (avanço físico = média simples das fases do
// cronograma) e nenhuma parte fala com o FirestoreService.

/// Caminhos que a central abre.
class _Rotas {
  const _Rotas(this.obraId);

  final String obraId;

  String get _base => '/obras/$obraId';
  String get lancamentos => '$_base/lancamentos';

  /// A fila de aprovação: a lista de lançamentos já no filtro "pendentes".
  String get fila => '$_base/lancamentos?filtro=pendentes';
  String get novoLancamento => '$_base/lancamentos/novo';
  String get diario => '$_base/diario';
  String get cronograma => '$_base/cronograma';
  String get estoque => '$_base/estoque';
  String get galeria => '$_base/galeria';
  String get relatorio => '$_base/relatorio';
}

/// O que a tela mostra, calculado uma vez por build.
class _ResumoObra {
  _ResumoObra({
    required this.obra,
    required this.cronograma,
    required this.cronogramaFalhou,
    required this.diario,
    required this.aprovados,
    required this.pendentes,
  })  : progresso = ProgressoMaquete.doCronograma(cronograma),
        fases = cronograma == null
            ? null
            : ([...cronograma]..sort((a, b) => a.ordem.compareTo(b.ordem)));

  final ObraModel obra;
  final List<CronogramaFaseModel>? cronograma;

  /// A leitura do cronograma deu erro: ele não vai chegar.
  final bool cronogramaFalhou;
  final List<DiarioEntradaModel>? diario;
  final int aprovados;
  final int pendentes;
  final ProgressoMaquete progresso;

  /// O cronograma em ordem (nulo enquanto carrega).
  final List<CronogramaFaseModel>? fases;

  bool get temCronograma => fases != null && fases!.isNotEmpty;

  /// O cronograma ainda não chegou (e vai chegar).
  bool get carregandoCronograma => fases == null && !cronogramaFalhou;

  /// Avanço físico (0 a 100), a média simples das fases; nulo sem
  /// cronograma.
  int? get avancoFisico => temCronograma ? progresso.percentualObra : null;

  /// A fase em que a obra está: a primeira começada e não terminada; se
  /// nenhuma, a primeira que falta. Nula sem cronograma ou com tudo pronto.
  CronogramaFaseModel? get faseAtual {
    final lista = fases;
    if (lista == null) return null;
    for (final f in lista) {
      if (f.percentualConcluido > 0 && f.percentualConcluido < 100) return f;
    }
    for (final f in lista) {
      if (f.percentualConcluido < 100) return f;
    }
    return null;
  }

  /// Valor da célula FASE do carimbo: a fase atual, ou o status da obra.
  String get textoFase {
    if (carregandoCronograma) return '…';
    final atual = faseAtual;
    if (atual != null) return atual.nome;
    if (temCronograma) return 'Fases concluídas';
    return obra.status.label;
  }

  /// "25 de 47": semana atual contada do início, e o total até a previsão
  /// de término.
  String get textoSemana {
    int dias(DateTime de, DateTime ate) =>
        (DateUtils.dateOnly(ate).difference(DateUtils.dateOnly(de)).inHours /
                24)
            .round();
    final total =
        (dias(obra.dataInicio, obra.previsaoTermino) / 7).ceil().clamp(1, 9999);
    final hoje = DateTime.now();
    final decorridos = dias(obra.dataInicio, hoje);
    if (decorridos < 0) {
      return 'começa ${Formatters.dataCurta(obra.dataInicio)}';
    }
    if (obra.status == StatusObra.concluida) return '$total previstas';
    return '${decorridos ~/ 7 + 1} de $total';
  }

  String get resumoLancamentos {
    final textoPendentes = switch (pendentes) {
      0 => 'nenhum pendente',
      1 => '1 pendente',
      _ => '$pendentes pendentes',
    };
    return '$aprovados ${aprovados == 1 ? 'aprovado' : 'aprovados'} · '
        '$textoPendentes';
  }

  String get resumoCronograma {
    if (fases == null) return 'Fases da obra e o avanço de cada uma';
    if (!temCronograma) return 'Nenhuma fase cadastrada';
    final atual = faseAtual;
    if (atual == null) return 'Todas as fases concluídas';
    return '${atual.nome} em ${atual.percentualConcluido}% · '
        'obra em ${progresso.percentualObra}%';
  }

  String get resumoDiario {
    final lista = diario;
    if (lista == null) return 'Clima, equipe e o que foi feito no dia';
    if (lista.isEmpty) return 'Nenhum registro ainda';
    final ultimo = lista.first.data;
    if (DateUtils.isSameDay(ultimo, DateTime.now())) {
      return 'Hoje já tem registro';
    }
    return 'Último registro em ${Formatters.dataCurta(ultimo)}';
  }
}

/// Origem do lançamento, em minúsculas para ir depois do fornecedor.
String _origem(OrigemLancamento origem) => switch (origem) {
      OrigemLancamento.manual => 'digitado',
      OrigemLancamento.ocr => 'nota fiscal',
      OrigemLancamento.voz => 'por voz',
    };

/// "Casa do Construtor · nota fiscal".
String _apoioLancamento(LancamentoModel l) {
  final partes = [
    if (l.fornecedorNome != null && l.fornecedorNome!.trim().isNotEmpty)
      l.fornecedorNome!.trim(),
    _origem(l.origem),
  ];
  final texto = partes.join(' · ');
  return texto[0].toUpperCase() + texto.substring(1);
}

/// Enquanto a obra não chega: folhas com a forma do conteúdo.
class _AbrindoObra extends StatelessWidget {
  const _AbrindoObra();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(Espaco.margem),
        children: const [
          EsqueletoFolha(
            linhas: 2,
            comValor: false,
            rotuloSemantico: 'Abrindo a obra',
          ),
          SizedBox(height: Espaco.e16),
          // O leitor de tela diz "Abrindo a obra" uma vez, não duas.
          ExcludeSemantics(child: EsqueletoFolha()),
        ],
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({
    required this.icone,
    required this.texto,
    this.destrutivo = false,
  });

  final IconData icone;
  final String texto;
  final bool destrutivo;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final cor = destrutivo ? c.revisao : c.grafite;
    return Row(
      children: [
        Icon(icone, size: 24, color: cor),
        const SizedBox(width: Espaco.e12),
        Flexible(
          child: Text(
            texto,
            style: Tipografia.corpo.copyWith(
              color: cor,
              fontWeight: destrutivo ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _NaMargem extends StatelessWidget {
  const _NaMargem(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Espaco.margem),
        child: child,
      );
}

/// Seção da prancha: a linha de cota com o nome e o conteúdo embaixo.
class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Espaco.margem,
        Espaco.e24,
        Espaco.margem,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Um nó só com o título: sem o container, o "título" subia para o
          // nó da seção inteira, e o leitor de tela lia o orçamento todo
          // como cabeçalho.
          Semantics(
            header: true,
            container: true,
            child: LinhaCota(legenda: titulo),
          ),
          const SizedBox(height: Espaco.e16),
          child,
        ],
      ),
    );
  }
}

/// O carimbo da prancha: obra, endereço e cliente; fase e semana.
class _CarimboObra extends StatelessWidget {
  const _CarimboObra({required this.obra, required this.resumo});

  final ObraModel obra;
  final _ResumoObra resumo;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final apoio = Tipografia.apoio.copyWith(color: c.grafite2);
    final selo = switch (obra.status) {
      StatusObra.emAndamento => null,
      StatusObra.pausada =>
        const SeloStatus(StatusSelo.aviso, texto: 'Obra pausada'),
      StatusObra.concluida =>
        const SeloStatus(StatusSelo.aprovado, texto: 'Obra concluída'),
    };
    return _NaMargem(
      Carimbo(
        linhas: [
          [
            CelulaCarimbo(
              rotulo: 'Obra',
              conteudo: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // O título da tela (o AppBar não repete o nome).
                  Semantics(
                    header: true,
                    child: Text(
                      obra.nome,
                      style: Tipografia.tituloTela.copyWith(color: c.grafite),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: Espaco.e4),
                  Text(obra.endereco, style: apoio),
                  if (obra.cliente != null && obra.cliente!.trim().isNotEmpty)
                    Text('Cliente: ${obra.cliente}', style: apoio),
                ],
              ),
            ),
          ],
          [
            CelulaCarimbo(
              rotulo: 'Fase',
              valor: resumo.textoFase,
              conteudo: selo == null
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          resumo.textoFase,
                          style:
                              Tipografia.subtitulo.copyWith(color: c.grafite),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: Espaco.e4),
                        selo,
                      ],
                    ),
            ),
            CelulaCarimbo(rotulo: 'Semana', valor: resumo.textoSemana),
          ],
        ],
      ),
    );
  }
}

/// A maquete com o avanço vindo do cronograma e, embaixo, a legenda do
/// tracejado e o avanço físico.
class _MaqueteComAvanco extends StatelessWidget {
  const _MaqueteComAvanco({required this.resumo});

  final _ResumoObra resumo;

  /// Proporção das imagens de reserva (largura / altura).
  static const double _proporcaoImagem = 1.5;

  /// Quanto da altura da imagem o desenho ocupa: em todos os estados, claro
  /// e escuro, ele vai de 7,5% a 92,4% da altura; o resto é papel.
  static const double _alturaDoDesenho = 0.87;

  /// Recorte máximo: abaixo disso o telhado e o canto do tabuleiro somem.
  static const double _recorteMaximo = 0.8;

  /// A altura da imagem e a parte dela que aparece.
  ///
  /// A imagem ocupa a largura da tela: mais estreita, a sombra do tabuleiro,
  /// que a imagem corta na borda direita, apareceria como um degrau no meio
  /// do papel. Para a maquete não tomar a primeira tela, as faixas de papel
  /// de cima e de baixo da imagem ficam de fora (recorte), e a parte visível
  /// não passa de 32% da altura da tela. Só numa tela larga e baixa
  /// (paisagem, tablet) a imagem fica mais estreita que a tela.
  static ({double imagem, double visivel}) _medidas(BuildContext context) {
    final tela = MediaQuery.sizeOf(context);
    final limite = math.max(tela.height * 0.32, 160.0);
    final imagem = math.min(
      math.min(tela.width / _proporcaoImagem, 320.0),
      limite / _recorteMaximo,
    );
    return (
      imagem: imagem,
      visivel: math.min(imagem * _alturaDoDesenho, limite),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final progresso = resumo.progresso;
    final avanco = resumo.avancoFisico;
    final medidas = _medidas(context);
    // Enquanto o cronograma não chega, só o papel no lugar da maquete: sem
    // ele a maquete abriria vazia ("sem cronograma", a casa toda em
    // desenho) e, um instante depois, trocaria para o avanço de verdade.
    // Essa troca não informa nada e, a cada vez que a central abre, faria a
    // casa parecer se construir sozinha.
    final carregando = resumo.carregandoCronograma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRect(
          child: SizedBox(
            height: medidas.visivel,
            child: carregando
                ? const SizedBox.expand()
                : OverflowBox(
                    minHeight: medidas.imagem,
                    maxHeight: medidas.imagem,
                    child: MaqueteObra(
                      progresso: progresso,
                      altura: medidas.imagem,
                      legenda: false,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: Espaco.e8),
        _NaMargem(
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: progresso.concluida
                    ? const SizedBox.shrink()
                    // Guarda o lugar enquanto carrega (a página não pula).
                    : Visibility(
                        visible: !carregando,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: const LegendaTracejada('ainda não construído'),
                      ),
              ),
              const SizedBox(width: Espaco.e12),
              if (resumo.fases != null)
                Semantics(
                  label: avanco == null
                      ? 'Sem cronograma'
                      : 'Avanço físico: $avanco% da obra',
                  excludeSemantics: true,
                  child: avanco == null
                      ? Text(
                          'Sem cronograma',
                          style: Tipografia.apoio.copyWith(color: c.grafite2),
                        )
                      : Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$avanco%',
                                style: Tipografia.titulo
                                    .copyWith(color: c.grafite),
                              ),
                              TextSpan(
                                text: ' da obra',
                                style: Tipografia.apoio
                                    .copyWith(color: c.grafite2),
                              ),
                            ],
                          ),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Folha dos lançamentos pendentes: hachura, quantos e quanto, e até três
/// linhas. Tocar abre a fila de aprovação.
class _FolhaPendentes extends StatelessWidget {
  const _FolhaPendentes({
    this.rotulo,
    required this.titulo,
    required this.pendentes,
    required this.total,
    required this.destaque,
    required this.aoTocar,
  });

  static const int _maximo = 3;

  /// Rótulo em caixa alta acima do título (de quem são os lançamentos).
  final String? rotulo;
  final String titulo;
  final List<LancamentoModel> pendentes;
  final double total;
  final bool destaque;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final visiveis = pendentes.take(_maximo).toList();
    final resto = pendentes.length - visiveis.length;
    return Folha(
      destaque: destaque,
      preenchimento: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CabecalhoPendentes(
            rotulo: rotulo,
            titulo: titulo,
            total: Formatters.moeda(total),
            aoTocar: aoTocar,
          ),
          for (var i = 0; i < visiveis.length; i++)
            LinhaLista(
              titulo: visiveis[i].descricao,
              apoio: _apoioLancamento(visiveis[i]),
              valor: Formatters.moeda(visiveis[i].valor),
              aoTocar: aoTocar,
              margemHorizontal: Espaco.e12,
              divisoria: i < visiveis.length - 1 || resto > 0,
            ),
          if (resto > 0)
            LinhaLista(
              titulo: 'e mais $resto ${resto == 1 ? 'gasto' : 'gastos'}',
              aoTocar: aoTocar,
              margemHorizontal: Espaco.e12,
            ),
        ],
      ),
    );
  }
}

class _CabecalhoPendentes extends StatelessWidget {
  const _CabecalhoPendentes({
    this.rotulo,
    required this.titulo,
    required this.total,
    required this.aoTocar,
  });

  final String? rotulo;
  final String titulo;
  final String total;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final estilo = Tipografia.subtitulo.copyWith(color: c.grafite);
    // Tocável como as linhas embaixo (abre a mesma fila). Sem a seta das
    // linhas: com ela, "3 gastos para aprovar" quebra em duas linhas já em
    // 390 dp.
    return AreaPressionavel(
      aoTocar: aoTocar,
      escala: 1,
      dicaSemantica: 'Abre a fila de aprovação',
      construtor: (context, e) => AnimatedContainer(
        duration: context.duracao(Movimento.rapido),
        constraints: const BoxConstraints(minHeight: Alvo.mestre),
        padding: const EdgeInsets.all(Espaco.e12),
        decoration: BoxDecoration(
          color: e.pressionado ? c.folhaRebaixada : const Color(0x00000000),
          border: Border(bottom: BorderSide(color: c.grade, width: Traco.fino)),
        ),
        foregroundDecoration: e.focado
            ? BoxDecoration(border: Border.all(color: c.marcaTexto, width: 3))
            : null,
        child: Row(
          children: [
            const CaixaHachurada(largura: 16, altura: 32),
            const SizedBox(width: Espaco.e12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (rotulo != null) Rotulo(rotulo!),
                  ParComValor(
                    esquerda: Text(titulo, style: estilo),
                    direita: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(total, style: estilo, maxLines: 1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A previsão do orçamento numa linha: o risco com forma e texto, a
/// projeção para o fim da obra e a recomendação.
class _LinhaPrevisao extends StatelessWidget {
  const _LinhaPrevisao({required this.previsao, required this.fimPrevisto});

  final PrevisaoOrcamento previsao;

  /// A previsão de término da obra: a data em que o orçamento acaba só é
  /// "estouro" se cair antes dela.
  final DateTime fimPrevisto;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final selo = switch (previsao.risco) {
      NivelRisco.ok => StatusSelo.aprovado,
      NivelRisco.atencao => StatusSelo.aviso,
      NivelRisco.alto => StatusSelo.recusado,
    };
    final estouro = previsao.dataEstouroPrevista;
    // "Sob controle · estouro estimado em 12/05/2027" se contradiz quando a
    // data é depois do fim da obra: aí o orçamento só acabaria se a obra
    // atrasasse, e a frase diz isso. A condição é a mesma com que o serviço
    // decide o risco (o estouro só é "alto" até a previsão de término, ou
    // com o orçamento já estourado), para a frase nunca desmentir o selo.
    final depoisDoTermino = estouro != null &&
        previsao.risco != NivelRisco.alto &&
        estouro.isAfter(fimPrevisto);
    final textoEstouro = estouro == null
        ? null
        : depoisDoTermino
            ? ' · no ritmo atual, o orçamento acaba em '
                '${Formatters.data(estouro)}, depois do término previsto'
            : ' · estouro estimado em ${Formatters.data(estouro)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Rotulo('Previsão para o fim da obra'),
        const SizedBox(height: Espaco.e8),
        SeloStatus(selo, texto: previsao.risco.label),
        if (previsao.dadosSuficientes) ...[
          const SizedBox(height: Espaco.e8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Projeção: '),
                TextSpan(
                  text: Formatters.moeda(previsao.gastoProjetadoFinal),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (textoEstouro != null) TextSpan(text: textoEstouro),
              ],
            ),
            style: Tipografia.corpo.copyWith(color: c.grafite),
          ),
        ],
        const SizedBox(height: Espaco.e4),
        Text(
          previsao.recomendacao,
          style: Tipografia.apoio.copyWith(color: c.grafite2),
        ),
      ],
    );
  }
}

/// Os módulos da obra como lista, cada um com um resumo do que tem dentro.
class _ListaModulos extends StatelessWidget {
  const _ListaModulos({required this.resumo, required this.rotas});

  final _ResumoObra resumo;
  final _Rotas rotas;

  @override
  Widget build(BuildContext context) {
    final itens = <(IconData, String, String, String)>[
      (
        Icons.receipt_long_outlined,
        'Lançamentos',
        resumo.resumoLancamentos,
        rotas.lancamentos,
      ),
      // O menu_book "outlined" sai cheio na fonte do Material; a página de
      // agenda com linhas é de traço, como os outros.
      (Icons.event_note_outlined, 'Diário', resumo.resumoDiario, rotas.diario),
      (
        Icons.view_timeline_outlined,
        'Cronograma',
        resumo.resumoCronograma,
        rotas.cronograma,
      ),
      (
        Icons.inventory_2_outlined,
        'Estoque',
        'Materiais e quando acabam',
        rotas.estoque,
      ),
      (
        Icons.photo_library_outlined,
        'Galeria',
        'Fotos do canteiro',
        rotas.galeria,
      ),
      (
        Icons.summarize_outlined,
        'Relatório da semana',
        'Resumo e perguntas sobre a obra',
        rotas.relatorio,
      ),
    ];
    return Folha(
      preenchimento: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < itens.length; i++)
            LinhaLista(
              icone: itens[i].$1,
              titulo: itens[i].$2,
              apoio: itens[i].$3,
              aoTocar: () => context.push(itens[i].$4),
              margemHorizontal: Espaco.e12,
              divisoria: i < itens.length - 1,
            ),
        ],
      ),
    );
  }
}

/// Os códigos de convite da equipe e do cliente; tocar copia (o convite do
/// cliente é gerado na primeira vez).
class _Convites extends StatelessWidget {
  const _Convites({required this.obra});

  final ObraModel obra;

  @override
  Widget build(BuildContext context) {
    final semCodigoCliente = obra.codigoCliente.isEmpty;
    return Folha(
      preenchimento: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LinhaCodigo(
            icone: Icons.engineering_outlined,
            titulo: 'Código da equipe',
            apoio: 'Para o mestre de obras entrar na obra',
            codigo: obra.codigoConvite,
            aoTocar: () => _convidarEquipe(context, obra),
            divisoria: true,
          ),
          _LinhaCodigo(
            icone: Icons.holiday_village_outlined,
            titulo: semCodigoCliente ? 'Convidar cliente' : 'Código do cliente',
            apoio: semCodigoCliente
                ? 'Gera um código para o cliente acompanhar a obra, sem ver '
                    'custos'
                : 'O cliente acompanha a obra sem ver custos',
            codigo: semCodigoCliente ? null : obra.codigoCliente,
            aoTocar: () => _convidarCliente(context, obra),
          ),
        ],
      ),
    );
  }
}

/// Linha de lista com o código de convite em PlexMono à direita e o ícone
/// de copiar no lugar da seta. (A `LinhaLista` do design system só aceita o
/// valor como texto na Archivo; o código pede a fonte de código.)
class _LinhaCodigo extends StatelessWidget {
  const _LinhaCodigo({
    required this.icone,
    required this.titulo,
    required this.apoio,
    required this.codigo,
    required this.aoTocar,
    this.divisoria = false,
  });

  final IconData icone;
  final String titulo;
  final String apoio;

  /// Nulo: ainda não existe (tocar gera).
  final String? codigo;
  final VoidCallback aoTocar;
  final bool divisoria;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final cod = codigo;
    return AreaPressionavel(
      aoTocar: aoTocar,
      escala: 1,
      vibrar: true,
      rotuloSemantico: cod == null
          ? '$titulo. $apoio'
          : '$titulo: ${cod.split('').join(' ')}. $apoio',
      dicaSemantica: cod == null ? 'Gera e copia o código' : 'Copia o código',
      construtor: (context, e) => AnimatedContainer(
        duration: context.duracao(Movimento.rapido),
        constraints: const BoxConstraints(minHeight: Alvo.principal),
        padding: const EdgeInsets.all(Espaco.e12),
        decoration: BoxDecoration(
          color: e.pressionado ? c.folhaRebaixada : const Color(0x00000000),
          border: divisoria
              ? Border(bottom: BorderSide(color: c.grade, width: Traco.fino))
              : null,
        ),
        foregroundDecoration: e.focado
            ? BoxDecoration(border: Border.all(color: c.marcaTexto, width: 3))
            : null,
        child: Row(
          children: [
            Icon(icone, size: 24, color: c.grafite),
            const SizedBox(width: Espaco.e12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titulo,
                    style: Tipografia.corpoForte.copyWith(color: c.grafite),
                  ),
                  // O código embaixo do título, não numa coluna à direita:
                  // em 360 dp com fonte grande, a coluna espremia o título
                  // e o apoio em três linhas cada.
                  if (cod != null)
                    Text(
                      cod,
                      style: Tipografia.codigo.copyWith(
                        color: c.grafite,
                        fontSize: 20,
                        letterSpacing: 2,
                      ),
                    ),
                  const SizedBox(height: Espaco.e4),
                  Text(
                    apoio,
                    style: Tipografia.apoio.copyWith(color: c.grafite2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Espaco.e12),
            Icon(
              cod == null ? Icons.add_link : Icons.content_copy_outlined,
              size: 24,
              color: c.grafite,
            ),
          ],
        ),
      ),
    );
  }
}

/// Rodapé do dono: com pendentes, revisar é a ação principal e o "+" lança
/// um gasto; sem pendentes, lançar gasto.
class _BarraDono extends StatelessWidget {
  const _BarraDono({required this.pendentes, required this.rotas});

  final int pendentes;
  final _Rotas rotas;

  @override
  Widget build(BuildContext context) {
    if (pendentes == 0) {
      return BarraDeAcao(
        principal: BotaoMarca(
          rotulo: 'Lançar gasto',
          icone: Icons.add,
          grande: true,
          expandir: true,
          aoTocar: () => context.push(rotas.novoLancamento),
        ),
      );
    }
    return BarraDeAcao(
      principal: BotaoPrincipal(
        rotulo: 'Revisar $pendentes ${pendentes == 1 ? 'gasto' : 'gastos'}',
        grande: true,
        expandir: true,
        aoTocar: () => context.push(rotas.fila),
      ),
      secundaria: BotaoIcone(
        icone: Icons.add,
        rotulo: 'Lançar gasto',
        estilo: EstiloBotaoIcone.marca,
        tamanho: Alvo.principal,
        aoTocar: () => context.push(rotas.novoLancamento),
      ),
    );
  }
}

/// Rodapé do mestre: o canteiro de hoje em duas ações grandes.
class _BarraMestre extends StatelessWidget {
  const _BarraMestre({required this.rotas});

  final _Rotas rotas;

  @override
  Widget build(BuildContext context) {
    return BarraDeAcao(
      acima: const Rotulo('Canteiro hoje'),
      principal: Row(
        children: [
          Expanded(
            // Sem ícone: com ele, o rótulo quebra em duas linhas já em
            // 390 dp (meia largura menos o recuo do botão grande).
            child: BotaoMarca(
              rotulo: 'Lançar gasto',
              grande: true,
              expandir: true,
              aoTocar: () => context.push(rotas.novoLancamento),
            ),
          ),
          const SizedBox(width: Espaco.entreAlvos),
          Expanded(
            child: BotaoContorno(
              rotulo: 'Diário de hoje',
              grande: true,
              expandir: true,
              aoTocar: () => context.push(rotas.diario),
            ),
          ),
        ],
      ),
    );
  }
}
