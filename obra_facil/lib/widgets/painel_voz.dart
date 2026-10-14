import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/app_colors.dart';
import '../services/ia/diario_voz_service.dart';
import '../services/ia/escuta_voz.dart';
import '../services/ia/voz_service.dart';
import '../utils/formatters.dart';

/// Um campo que a IA entendeu (ou não) enquanto o usuário fala.
class LinhaEntendida {
  final IconData icone;
  final String rotulo;

  /// null = ainda não entendi este campo.
  final String? valor;

  const LinhaEntendida(this.icone, this.rotulo, this.valor);
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
            r.valor != null ? Formatters.moeda(r.valor!) : null),
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
        TipoErroVoz.microfone || TipoErroVoz.audio => Icons.mic_off,
        TipoErroVoz.ocupado ||
        TipoErroVoz.muitasTentativas =>
          Icons.hourglass_empty,
        TipoErroVoz.pacoteOffline => Icons.download_for_offline,
        TipoErroVoz.semInternet => Icons.wifi_off,
        TipoErroVoz.desconhecido => Icons.error_outline,
      };

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final erro = _erro;
    // Erro sem nada ouvido: não há o que concluir, só tentar de novo.
    final soTentarDeNovo = erro != null && _transcricao.isEmpty && !_ouvindo;

    Widget microfone = Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: _ouvindo
            ? AppColors.laranja
            : (erro != null ? AppColors.erro : AppColors.laranja)
                .withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: Icon(_ouvindo ? Icons.mic : Icons.mic_off,
          size: 40, color: Colors.white),
    );
    if (_ouvindo) {
      microfone = microfone
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
              begin: 1.0, end: 1.12, duration: 600.ms, curve: Curves.easeInOut);
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewPadding.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: microfone),
            const SizedBox(height: 14),
            Text(
              _titulo,
              textAlign: TextAlign.center,
              style: textos.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              widget.exemplo,
              textAlign: TextAlign.center,
              style: textos.bodySmall
                  ?.copyWith(color: AppColors.textoDesabilitado),
            ),
            if (_online) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_outlined,
                      size: 15, color: AppColors.info),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Reconhecimento online do Google só nesta gravação',
                      style: textos.bodySmall?.copyWith(color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ],
            if (erro != null) ...[
              const SizedBox(height: 12),
              _CaixaDeErro(
                erro: erro,
                icone: _iconeDoErro(erro.tipo),
                onUsarOnline: erro.ofereceOnline ? _usarOnline : null,
              ),
            ],
            const SizedBox(height: 14),
            if (_transcricao.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.fundo,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '"$_transcricao"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: AppColors.amareloCapacete),
                ),
              ),
            if (_avisoConfianca != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: AppColors.alerta),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _avisoConfianca!,
                        style:
                            textos.bodySmall?.copyWith(color: AppColors.alerta),
                      ),
                    ),
                  ],
                ),
              ),
            // Interpretação ao vivo
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _interpretado == null
                  ? const SizedBox.shrink()
                  : Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.superficieAlta,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borda),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final linha in widget.linhas(_interpretado as T))
                            _LinhaEntendida(linha: linha),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton(
                  onPressed: _cancelar,
                  child: const Text('Cancelar'),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _concluirAoTerminar ? null : _regravar,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 14)),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(soTentarDeNovo ? 'Tentar de novo' : 'Regravar'),
                ),
                if (!soTentarDeNovo) ...[
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed:
                        _transcricao.trim().isEmpty || _concluirAoTerminar
                            ? null
                            : _concluir,
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        padding: const EdgeInsets.symmetric(horizontal: 18)),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Concluir'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// O erro da escuta com a saída dele. Quando falta o pacote offline, a
/// instrução para baixá-lo vem com a alternativa explícita do online —
/// a escolha é do usuário, o padrão continua no aparelho.
class _CaixaDeErro extends StatelessWidget {
  final ErroVoz erro;
  final IconData icone;
  final VoidCallback? onUsarOnline;

  const _CaixaDeErro({
    required this.erro,
    required this.icone,
    this.onUsarOnline,
  });

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.erro.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.erro.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, size: 18, color: AppColors.erro),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  erro.mensagem,
                  style: textos.bodySmall
                      ?.copyWith(color: AppColors.textoPrimario),
                ),
              ),
            ],
          ),
          if (onUsarOnline != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onUsarOnline,
              icon: const Icon(Icons.cloud_outlined, size: 18),
              label: const Text('Usar reconhecimento online do Google'),
            ),
            const SizedBox(height: 4),
            Text(
              'Só nesta gravação: o áudio vai para o Google. As próximas '
              'voltam a ser no aparelho.',
              textAlign: TextAlign.center,
              style: textos.bodySmall
                  ?.copyWith(color: AppColors.textoDesabilitado),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinhaEntendida extends StatelessWidget {
  final LinhaEntendida linha;

  const _LinhaEntendida({required this.linha});

  @override
  Widget build(BuildContext context) {
    final entendido = linha.valor != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(linha.icone,
              size: 16,
              color:
                  entendido ? AppColors.laranja : AppColors.textoDesabilitado),
          const SizedBox(width: 8),
          SizedBox(
            width: 86,
            child: Text(
              linha.rotulo,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textoSecundario),
            ),
          ),
          Expanded(
            child: Text(
              linha.valor ?? '—',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: entendido ? FontWeight.w600 : FontWeight.normal,
                    color: entendido
                        ? AppColors.textoPrimario
                        : AppColors.textoDesabilitado,
                  ),
            ),
          ),
          Icon(
            entendido ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 15,
            color: entendido ? AppColors.sucesso : AppColors.textoDesabilitado,
          ),
        ],
      ),
    );
  }
}
