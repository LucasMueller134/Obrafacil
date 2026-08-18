import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/app_colors.dart';
import '../services/ia/diario_voz_service.dart';
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
      linhas: (r) => [
        LinhaEntendida(Icons.payments, 'Valor',
            r.valor != null ? Formatters.moeda(r.valor!) : null),
        LinhaEntendida(Icons.event, 'Data',
            r.data != null ? _rotuloData(r.data!) : null),
        LinhaEntendida(r.categoria.icone, 'Categoria', r.categoria.label),
        LinhaEntendida(Icons.storefront, 'Fornecedor', r.fornecedorNome),
        LinhaEntendida(
            Icons.inventory_2,
            'Materiais',
            r.itens.isEmpty
                ? null
                : r.itens.map((i) => i.resumo).join(' · ')),
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
      linhas: (r) => [
        LinhaEntendida(Icons.cloud, 'Clima', r.clima),
        LinhaEntendida(Icons.groups, 'Pessoas',
            r.numeroPessoas != null ? '${r.numeroPessoas} no canteiro' : null),
        LinhaEntendida(Icons.construction, 'Fase', r.fase),
        LinhaEntendida(Icons.event, 'Dia',
            r.data != null ? _rotuloData(r.data!) : null),
      ],
    );

Future<T?> _abrirPainel<T>(
  BuildContext context,
  VozService voz, {
  required String exemplo,
  required T Function(String texto) interpretar,
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
  final List<LinhaEntendida> Function(T) linhas;

  const _PainelVoz({
    required this.voz,
    required this.exemplo,
    required this.interpretar,
    required this.linhas,
  });

  @override
  State<_PainelVoz<T>> createState() => _PainelVozState<T>();
}

class _PainelVozState<T> extends State<_PainelVoz<T>> {
  String _transcricao = '';
  T? _interpretado;
  bool _ouvindo = false;

  @override
  void initState() {
    super.initState();
    _comecar();
  }

  Future<void> _comecar() async {
    setState(() {
      _ouvindo = true;
      _transcricao = '';
      _interpretado = null;
    });
    await widget.voz.ouvir((texto, finalizou) {
      if (!mounted) return;
      setState(() {
        _transcricao = texto;
        // Interpretação ao vivo: o usuário vê os campos sendo
        // preenchidos enquanto fala.
        _interpretado =
            texto.trim().isEmpty ? null : widget.interpretar(texto);
        if (finalizou) _ouvindo = false;
      });
    });
  }

  Future<void> _regravar() async {
    await widget.voz.parar();
    await _comecar();
  }

  Future<void> _concluir() async {
    await widget.voz.parar();
    if (!mounted) return;
    final resultado = _transcricao.trim().isEmpty
        ? null
        : (_interpretado ?? widget.interpretar(_transcricao));
    Navigator.pop(context, resultado);
  }

  Future<void> _cancelar() async {
    await widget.voz.cancelar();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Widget microfone = Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: _ouvindo
            ? AppColors.laranja
            : AppColors.laranja.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: Icon(_ouvindo ? Icons.mic : Icons.mic_off,
          size: 40, color: Colors.white),
    );
    if (_ouvindo) {
      microfone = microfone.animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
          begin: 1.0, end: 1.12, duration: 600.ms, curve: Curves.easeInOut);
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewPadding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: microfone),
          const SizedBox(height: 14),
          Text(
            _ouvindo
                ? 'Pode falar com calma — estou ouvindo'
                : _transcricao.isEmpty
                    ? 'Não ouvi nada. Tente de novo.'
                    : 'Confira o que entendi e conclua',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            widget.exemplo,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textoDesabilitado),
          ),
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
                onPressed: _regravar,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 14)),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Regravar'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _transcricao.trim().isEmpty ? null : _concluir,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 18)),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Concluir'),
              ),
            ],
          ),
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
