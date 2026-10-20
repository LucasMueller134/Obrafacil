import 'dart:async';

import 'package:flutter/material.dart';

import '../design/design.dart';
import '../services/ia/diario_voz_service.dart';
import '../services/ia/escuta_voz.dart';
import '../services/ia/voz_service.dart';
import '../utils/formatters.dart';
import 'botao_ia.dart';

/// Um campo que a IA entendeu (ou não) enquanto o usuário fala.
class LinhaEntendida {
  final IconData icone;
  final String rotulo;

  /// null = ainda não entendi este campo.
  final String? valor;

  /// Valor em dinheiro: vai na fonte dos números (a Atkinson corta o zero,
  /// e em R\$ pequeno o zero cortado parece valor riscado).
  final bool dinheiro;

  const LinhaEntendida(this.icone, this.rotulo, this.valor,
      {this.dinheiro = false});
}

/// Abre o painel de voz do lançamento, com interpretação ao vivo.
/// Retorna o lançamento interpretado, ou null se o usuário cancelar.
Future<LancamentoPorVoz?> mostrarPainelVoz(
        BuildContext context, VozService voz) =>
    _abrirPainel<LancamentoPorVoz>(
      context,
      voz,
      exemplo: 'Ex.: "Ontem comprei dez sacos de cimento por trezentos e '
          'cinquenta reais no Depósito São José"',
      interpretar: VozService.interpretar,
      interpretarHipoteses: VozService.interpretarHipoteses,
      transcricaoDe: (r) => r.transcricao,
      linhas: (r) => [
        LinhaEntendida(Icons.payments, 'Valor',
            r.valor != null ? Formatters.moeda(r.valor!) : null,
            dinheiro: true),
        LinhaEntendida(
            Icons.event, 'Data', r.data != null ? _rotuloData(r.data!) : null),
        LinhaEntendida(r.categoria.icone, 'Categoria', r.categoria.label),
        LinhaEntendida(Icons.storefront, 'Fornecedor', r.fornecedorNome),
        LinhaEntendida(Icons.inventory_2, 'Materiais',
            r.itens.isEmpty ? null : r.itens.map((i) => i.resumo).join(' · ')),
      ],
    );

/// Abre o painel de voz do diário de obra: o encarregado conta o dia e a
/// IA separa clima, equipe, fase e data.
Future<DiarioPorVoz?> mostrarPainelVozDiario(
        BuildContext context, VozService voz) =>
    _abrirPainel<DiarioPorVoz>(
      context,
      voz,
      exemplo: 'Ex.: "Hoje choveu de manhã, trabalharam três pedreiros e '
          'dois serventes, terminamos o reboco da fachada"',
      interpretar: DiarioVozService.interpretar,
      interpretarHipoteses: DiarioVozService.interpretarHipoteses,
      transcricaoDe: (r) => r.transcricao,
      linhas: (r) => [
        LinhaEntendida(Icons.cloud, 'Clima', r.clima),
        LinhaEntendida(Icons.groups, 'Pessoas',
            r.numeroPessoas != null ? '${r.numeroPessoas} no canteiro' : null),
        LinhaEntendida(Icons.construction, 'Fase', r.fase),
        LinhaEntendida(
            Icons.event, 'Dia', r.data != null ? _rotuloData(r.data!) : null),
      ],
    );

Future<T?> _abrirPainel<T>(
  BuildContext context,
  VozService voz, {
  required String exemplo,
  required T Function(String texto) interpretar,
  required T Function(List<(String, double)> hipoteses) interpretarHipoteses,
  required String Function(T) transcricaoDe,
  required List<LinhaEntendida> Function(T) linhas,
}) async {
  final ok = await voz.inicializar();
  if (!context.mounted) return null;
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Reconhecimento de voz indisponível. '
            'Verifique a permissão do microfone nas configurações.')));
    return null;
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    // Com a fonte grande a folha cresce até o topo: não passa por baixo da
    // barra de status.
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _PainelVoz<T>(
      voz: voz,
      exemplo: exemplo,
      interpretar: interpretar,
      interpretarHipoteses: interpretarHipoteses,
      transcricaoDe: transcricaoDe,
      linhas: linhas,
    ),
  );
}

/// "Hoje"/"Ontem" comunicam melhor que a data por extenso.
String _rotuloData(DateTime data) {
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final dia = DateTime(data.year, data.month, data.day);
  final diff = hoje.difference(dia).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Ontem';
  return Formatters.data(data);
}

class _PainelVoz<T> extends StatefulWidget {
  final VozService voz;
  final String exemplo;
  final T Function(String texto) interpretar;
  final T Function(List<(String, double)> hipoteses) interpretarHipoteses;
  final String Function(T) transcricaoDe;
  final List<LinhaEntendida> Function(T) linhas;

  const _PainelVoz({
    required this.voz,
    required this.exemplo,
    required this.interpretar,
    required this.interpretarHipoteses,
    required this.transcricaoDe,
    required this.linhas,
  });

  @override
  State<_PainelVoz<T>> createState() => _PainelVozState<T>();
}

class _PainelVozState<T> extends State<_PainelVoz<T>> {
  String _transcricao = '';
  T? _interpretado;
  bool _ouvindo = false;

  /// Esta gravação usa o reconhecimento online do Google — só quando o
  /// usuário escolheu, depois de ver que falta o pacote offline.
  bool _online = false;
  ErroVoz? _erro;
  String? _avisoConfianca;

  /// Último resultado recebido: se o final não chegar, a interpretação
  /// fecha com ele.
  ResultadoVoz? _ultimo;
  bool _interpretacaoFinal = false;

  /// "Concluir" tocado com o microfone aberto: o painel fecha quando o
  /// resultado final chegar, para aproveitar todas as hipóteses dele.
  bool _concluirAoTerminar = false;
  Timer? _limiteConclusao;
  bool _saiu = false;

  /// Número da gravação: o que chega de uma gravação anterior (antes do
  /// "Regravar") não mexe na atual.
  int _gravacao = 0;

  @override
  void initState() {
    super.initState();
    _comecar();
  }

  @override
  void dispose() {
    _limiteConclusao?.cancel();
    // Fechado pelo "voltar" do Android: o microfone não fica aberto.
    if (!_saiu) unawaited(widget.voz.cancelar());
    super.dispose();
  }

  Future<void> _comecar({bool online = false}) async {
    final gravacao = ++_gravacao;
    setState(() {
      _ouvindo = true;
      _online = online;
      _erro = null;
      _avisoConfianca = null;
      _transcricao = '';
      _interpretado = null;
      _ultimo = null;
      _interpretacaoFinal = false;
    });
    bool atual() => mounted && gravacao == _gravacao;
    await widget.voz.ouvir(
      (_, __) {}, // o painel lê o resultado completo em onResultado
      online: online,
      onResultado: (r) {
        if (atual()) _aoResultado(r);
      },
      onErro: (e) {
        if (atual()) setState(() => _erro = e);
      },
      onFim: () {
        if (atual()) _aoTerminar();
      },
    );
  }

  void _aoResultado(ResultadoVoz r) {
    if (r.hipoteses.isEmpty) return;
    _ultimo = r;
    if (r.finalizou) {
      _interpretarFinal(r);
      return;
    }
    setState(() {
      _transcricao = r.texto;
      // Interpretação ao vivo: o usuário vê os campos sendo
      // preenchidos enquanto fala.
      _interpretado =
          r.texto.trim().isEmpty ? null : widget.interpretar(r.texto);
    });
  }

  /// Com a fala completa, a IA compara todas as hipóteses do reconhecedor
  /// e mostra a que ela entende melhor — e avisa quando nem o reconhecedor
  /// tem certeza do que ouviu.
  void _interpretarFinal(ResultadoVoz r) {
    if (_interpretacaoFinal) return;
    _interpretacaoFinal = true;
    final escolhido = widget.interpretarHipoteses(r.hipoteses);
    final texto = widget.transcricaoDe(escolhido);
    setState(() {
      _ouvindo = false;
      _transcricao = texto;
      _interpretado = texto.trim().isEmpty ? null : escolhido;
      _avisoConfianca = ErroVoz.avisoDeConfianca(r.confiancaDe(texto));
    });
  }

  void _aoTerminar() {
    final ultimo = _ultimo;
    if (ultimo != null) _interpretarFinal(ultimo);
    setState(() => _ouvindo = false);
    if (_concluirAoTerminar) _sair();
  }

  Future<void> _regravar() async {
    _concluirAoTerminar = false;
    _limiteConclusao?.cancel();
    // A nova gravação volta para o aparelho: o online vale para uma só.
    await widget.voz.cancelar();
    if (mounted) await _comecar();
  }

  Future<void> _usarOnline() async {
    await widget.voz.cancelar();
    if (mounted) await _comecar(online: true);
  }

  Future<void> _concluir() async {
    if (!_ouvindo) return _sair();
    setState(() => _concluirAoTerminar = true);
    // Se o resultado final não vier, fecha com o que já foi ouvido.
    _limiteConclusao = Timer(const Duration(seconds: 4), _sair);
    await widget.voz.parar();
  }

  void _sair() {
    if (_saiu || !mounted) return;
    _saiu = true;
    _limiteConclusao?.cancel();
    // O final não veio no prazo: fecha com o que já foi ouvido e solta o
    // microfone.
    if (_ouvindo) unawaited(widget.voz.cancelar());
    final resultado = _transcricao.trim().isEmpty
        ? null
        : (_interpretado ?? widget.interpretar(_transcricao));
    Navigator.pop(context, resultado);
  }

  Future<void> _cancelar() async {
    _saiu = true;
    _limiteConclusao?.cancel();
    await widget.voz.cancelar();
    if (mounted) Navigator.pop(context);
  }

  String get _titulo {
    if (_ouvindo) {
      return _online
          ? 'Pode falar — ouvindo pelo Google (online)'
          : 'Pode falar com calma — estou ouvindo';
    }
    if (_transcricao.isEmpty) {
      return _erro != null
          ? 'Não deu para ouvir'
          : 'Não ouvi nada. Tente de novo.';
    }
    return 'Confira o que entendi e conclua';
  }

  static IconData _iconeDoErro(TipoErroVoz tipo) => switch (tipo) {
        TipoErroVoz.naoEntendi => Icons.hearing,
        TipoErroVoz.microfone || TipoErroVoz.audio => Icons.mic_off_outlined,
        TipoErroVoz.ocupado ||
        TipoErroVoz.muitasTentativas =>
          Icons.hourglass_empty,
        TipoErroVoz.pacoteOffline => Icons.download_for_offline_outlined,
        TipoErroVoz.semInternet => Icons.wifi_off,
        TipoErroVoz.desconhecido => Icons.error_outline,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final erro = _erro;
    // Erro sem nada ouvido: não há o que concluir, só tentar de novo.
    final soTentarDeNovo = erro != null && _transcricao.isEmpty && !_ouvindo;
    final seguro = MediaQuery.paddingOf(context);
    final interpretado = _interpretado;

    final conteudo = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _Microfone(ouvindo: _ouvindo, erro: erro != null)),
        const SizedBox(height: Espaco.e8),
        Semantics(
          liveRegion: true,
          child: Text(
            _titulo,
            textAlign: TextAlign.center,
            style: Tipografia.titulo.copyWith(color: c.grafite),
          ),
        ),
        // O exemplo ajuda a começar; com a fala na tela, só ocuparia lugar.
        if (_transcricao.isEmpty) ...[
          const SizedBox(height: Espaco.e4),
          Text(
            widget.exemplo,
            textAlign: TextAlign.center,
            style: Tipografia.apoio.copyWith(color: c.grafite2),
          ),
        ],
        if (_online) ...[
          const SizedBox(height: Espaco.e12),
          const Center(
            child: NotaRevisao(
              'Reconhecimento online do Google só nesta gravação',
              tipo: TipoNota.marca,
              icone: Icons.cloud_outlined,
            ),
          ),
        ],
        if (erro != null) ...[
          const SizedBox(height: Espaco.e16),
          _CaixaDeErro(
            erro: erro,
            icone: _iconeDoErro(erro.tipo),
            onUsarOnline: erro.ofereceOnline ? _usarOnline : null,
          ),
        ],
        if (_transcricao.isNotEmpty) ...[
          const SizedBox(height: Espaco.e16),
          _Transcricao(texto: _transcricao),
        ],
        if (_avisoConfianca != null) ...[
          const SizedBox(height: Espaco.e12),
          AvisoIa(mensagem: _avisoConfianca!),
        ],
        // Interpretação ao vivo: os campos se marcam enquanto a pessoa fala.
        AnimatedSize(
          duration: context.duracao(Movimento.medio),
          curve: Movimento.entrar,
          alignment: Alignment.topCenter,
          child: interpretado == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Espaco.e16),
                  // Sem fundo próprio: na prancheta a folha que sobe já é
                  // a folha; numa tela do tema antigo, fica sobre a dela.
                  child: Folha(
                    cor: const Color(0x00000000),
                    preenchimento: const EdgeInsets.fromLTRB(
                      Espaco.e12,
                      Espaco.e12,
                      Espaco.e12,
                      Espaco.e8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Rotulo('O que entendi'),
                        const SizedBox(height: Espaco.e4),
                        for (final linha in widget.linhas(interpretado as T))
                          _LinhaEntendida(linha: linha, ouvindo: _ouvindo),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );

    // Os botões ficam fixos embaixo da folha, empilhados: em 360 dp os
    // três lado a lado não cabem. A ação que fecha com o que foi ouvido
    // vem primeiro, na largura toda; refazer e desistir ficam embaixo.
    final botoes = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (soTentarDeNovo)
          BotaoPrincipal(
            rotulo: 'Tentar de novo',
            icone: Icons.refresh,
            grande: true,
            expandir: true,
            aoTocar: _concluirAoTerminar ? null : _regravar,
          )
        else
          BotaoPrincipal(
            rotulo: 'Concluir',
            icone: Icons.check,
            grande: true,
            expandir: true,
            carregando: _concluirAoTerminar,
            aoTocar: _transcricao.trim().isEmpty ? null : _concluir,
          ),
        const SizedBox(height: Espaco.entreAlvos),
        Row(
          children: [
            if (!soTentarDeNovo) ...[
              Expanded(
                child: BotaoContorno(
                  rotulo: 'Regravar',
                  aoTocar: _concluirAoTerminar ? null : _regravar,
                ),
              ),
              const SizedBox(width: Espaco.entreAlvos),
            ],
            Expanded(
              child: BotaoContorno(rotulo: 'Cancelar', aoTocar: _cancelar),
            ),
          ],
        ),
      ],
    );

    final laterais = EdgeInsets.only(
      left: Espaco.margem + seguro.left,
      right: Espaco.margem + seguro.right,
    );
    return Padding(
      padding: EdgeInsets.only(
        top: Espaco.e24,
        bottom: MediaQuery.of(context).viewPadding.bottom + Espaco.e16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: laterais.copyWith(bottom: Espaco.e16),
              child: conteudo,
            ),
          ),
          // O traço do rodapé, como na BarraDeAcao: com a fonte grande o
          // conteúdo rola por baixo dele, e o corte fica visível (sem ele,
          // "O que entendi" sumia cortado ao meio, sem sinal de que rola).
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: c.grafite, width: Traco.fino),
              ),
            ),
            child: Padding(
              padding: laterais.copyWith(top: Espaco.e16),
              child: botoes,
            ),
          ),
        ],
      ),
    );
  }
}

/// O microfone: círculo de 88 dp. Ouvindo, fica laranja com o microfone
/// preto e um anel em volta; o anel pulsa (sai do círculo e some) só
/// enquanto escuta e fica parado com "reduzir animações". Parado, é só o
/// contorno com o microfone cortado; com erro, o contorno é vermelho.
class _Microfone extends StatefulWidget {
  final bool ouvindo;
  final bool erro;

  const _Microfone({required this.ouvindo, required this.erro});

  static const double diametro = 88;
  static const double area = 128;

  @override
  State<_Microfone> createState() => _MicrofoneState();
}

class _MicrofoneState extends State<_Microfone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sincronizar();
  }

  @override
  void didUpdateWidget(_Microfone antigo) {
    super.didUpdateWidget(antigo);
    _sincronizar();
  }

  void _sincronizar() {
    if (widget.ouvindo && !context.reduzirAnimacoes) {
      if (!_pulso.isAnimating) _pulso.repeat();
    } else {
      _pulso
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final ouvindo = widget.ouvindo;
    final contorno = widget.erro ? c.revisao : c.grafite;
    return Semantics(
      label: ouvindo ? 'Microfone aberto, ouvindo' : 'Microfone fechado',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: _Microfone.area,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (ouvindo)
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _PintorAnel(
                      pulso: _pulso,
                      cor: c.marcaTexto,
                      raioBase: _Microfone.diametro / 2 + Espaco.e8,
                      raioMaximo: _Microfone.area / 2 - Traco.forte,
                    ),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: context.duracao(Movimento.medio),
              curve: Movimento.entrar,
              width: _Microfone.diametro,
              height: _Microfone.diametro,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ouvindo ? c.marca : c.folha,
                border: ouvindo
                    ? null
                    : Border.all(color: contorno, width: Traco.forte),
              ),
              child: Icon(
                ouvindo ? Icons.mic_none : Icons.mic_off_outlined,
                size: 44,
                color: ouvindo ? c.sobreMarca : contorno,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Um anel fixo a [raioBase] e outro que cresce até [raioMaximo] e some.
class _PintorAnel extends CustomPainter {
  _PintorAnel({
    required this.pulso,
    required this.cor,
    required this.raioBase,
    required this.raioMaximo,
  }) : super(repaint: pulso);

  final Animation<double> pulso;
  final Color cor;
  final double raioBase;
  final double raioMaximo;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final tinta = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = Traco.forte
      ..color = cor;
    canvas.drawCircle(centro, raioBase, tinta);
    final t = Movimento.entrar.transform(pulso.value);
    if (t <= 0) return;
    canvas.drawCircle(
      centro,
      raioBase + (raioMaximo - raioBase) * t,
      tinta..color = cor.withValues(alpha: 1 - t),
    );
  }

  @override
  bool shouldRepaint(_PintorAnel antigo) =>
      antigo.pulso != pulso ||
      antigo.cor != cor ||
      antigo.raioBase != raioBase ||
      antigo.raioMaximo != raioMaximo;
}

/// A fala como ela chegou, em letra grande (20 sp) para conferir de longe.
class _Transcricao extends StatelessWidget {
  final String texto;

  const _Transcricao({required this.texto});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Container(
      padding: const EdgeInsets.only(left: Espaco.e12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: c.marca, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Rotulo('O que ouvi'),
          const SizedBox(height: Espaco.e4),
          Text(
            '"$texto"',
            style: Tipografia.corpo.copyWith(
              fontSize: 20,
              height: 1.35,
              color: c.grafite,
            ),
          ),
        ],
      ),
    );
  }
}

/// O erro da escuta com a saída dele. Quando falta o pacote offline, a
/// instrução para baixá-lo vem com a alternativa explícita do online —
/// a escolha é do usuário, o padrão continua no aparelho.
///
/// Vibra (Tato.erro) quando aparece e quando o erro muda: de luva e no
/// barulho, o mestre sente que a escuta parou.
class _CaixaDeErro extends StatefulWidget {
  final ErroVoz erro;
  final IconData icone;
  final VoidCallback? onUsarOnline;

  const _CaixaDeErro({
    required this.erro,
    required this.icone,
    this.onUsarOnline,
  });

  @override
  State<_CaixaDeErro> createState() => _CaixaDeErroState();
}

class _CaixaDeErroState extends State<_CaixaDeErro> {
  @override
  void initState() {
    super.initState();
    unawaited(Tato.erro());
  }

  @override
  void didUpdateWidget(_CaixaDeErro antigo) {
    super.didUpdateWidget(antigo);
    if (!identical(antigo.erro, widget.erro)) unawaited(Tato.erro());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final erro = widget.erro;
    final icone = widget.icone;
    final onUsarOnline = widget.onUsarOnline;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Espaco.e12),
        decoration: BoxDecoration(
          borderRadius: Raio.cantoPequeno,
          border: Border.all(color: c.revisao, width: Traco.fino),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icone, size: 22, color: c.revisao),
                ),
                const SizedBox(width: Espaco.e12),
                Expanded(
                  child: Text(
                    erro.mensagem,
                    style: Tipografia.corpo.copyWith(
                      color: c.grafite,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            if (onUsarOnline != null) ...[
              const SizedBox(height: Espaco.e12),
              BotaoContorno(
                rotulo: 'Usar reconhecimento online do Google',
                icone: Icons.cloud_outlined,
                expandir: true,
                aoTocar: onUsarOnline,
              ),
              const SizedBox(height: Espaco.e8),
              Text(
                'Só nesta gravação: o áudio vai para o Google. As próximas '
                'voltam a ser no aparelho.',
                textAlign: TextAlign.center,
                style: Tipografia.apoio.copyWith(color: c.grafite2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Uma linha da conferência: caixa marcada (entendido) ou vazia, o rótulo
/// e o valor. O estado vai na forma e no texto, não só na cor.
class _LinhaEntendida extends StatelessWidget {
  final LinhaEntendida linha;

  /// Ainda ouvindo: o que falta é "ainda não", não "não entendi".
  final bool ouvindo;

  const _LinhaEntendida({required this.linha, required this.ouvindo});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final valor = linha.valor;
    final entendido = valor != null;
    final texto = valor ?? (ouvindo ? 'ainda não' : 'não entendi');
    // O rótulo tem 112 dp na fonte normal e cresce com ela (senão
    // "FORNECEDOR" quebrava no meio com a fonte a 130%). Se rótulo e valor
    // não cabem lado a lado, o rótulo vai para cima do valor.
    final escala = MediaQuery.textScalerOf(context);
    final fatorRotulo = escala.scale(13) / 13;
    final fatorValor = escala.scale(17) / 17;
    final larguraRotulo = 112 * fatorRotulo;
    final caixa = Icon(
      entendido ? Icons.check_box_outlined : Icons.check_box_outline_blank,
      size: 24,
      color: entendido ? c.ok : c.traco,
    );
    final valorTexto = Text(
      texto,
      style: !entendido
          ? Tipografia.apoio.copyWith(color: c.grafite2, height: 1.55)
          : linha.dinheiro
              ? Tipografia.subtitulo.copyWith(color: c.grafite)
              : Tipografia.corpoForte.copyWith(color: c.grafite),
    );
    return Semantics(
      container: true,
      label: '${linha.rotulo}: $texto',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Espaco.e4),
        child: LayoutBuilder(
          builder: (context, limites) {
            final resto = limites.maxWidth - 24 - Espaco.e8;
            final ladoALado = resto >= larguraRotulo + 120 * fatorValor;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                caixa,
                const SizedBox(width: Espaco.e8),
                if (ladoALado) ...[
                  SizedBox(
                    width: larguraRotulo,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Rotulo(linha.rotulo),
                    ),
                  ),
                  Expanded(child: valorTexto),
                ] else
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Rotulo(linha.rotulo),
                        ),
                        valorTexto,
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
