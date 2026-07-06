import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/app_colors.dart';
import '../services/ia/voz_service.dart';
import '../utils/formatters.dart';

/// Abre o painel de lançamento por voz com interpretação ao vivo.
/// Retorna o lançamento interpretado, ou null se o usuário cancelar.
Future<LancamentoPorVoz?> mostrarPainelVoz(
    BuildContext context, VozService voz) async {
  final ok = await voz.inicializar();
  if (!context.mounted) return null;
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Reconhecimento de voz indisponível. '
            'Verifique a permissão do microfone nas configurações.')));
    return null;
  }
  return showModalBottomSheet<LancamentoPorVoz>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _PainelVoz(voz: voz),
  );
}

class _PainelVoz extends StatefulWidget {
  final VozService voz;

  const _PainelVoz({required this.voz});

  @override
  State<_PainelVoz> createState() => _PainelVozState();
}

class _PainelVozState extends State<_PainelVoz> {
  String _transcricao = '';
  LancamentoPorVoz? _interpretado;
  bool _ouvindo = false;

  /// "Hoje"/"Ontem" comunicam melhor que a data por extenso.
  static String _rotuloData(DateTime data) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dia = DateTime(data.year, data.month, data.day);
    final diff = hoje.difference(dia).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    return Formatters.data(data);
  }

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
            texto.trim().isEmpty ? null : VozService.interpretar(texto);
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
        : (_interpretado ?? VozService.interpretar(_transcricao));
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
      microfone = microfone
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
              begin: 1.0,
              end: 1.12,
              duration: 600.ms,
              curve: Curves.easeInOut);
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
            'Ex.: "Ontem comprei dez sacos de cimento por trezentos e '
            'cinquenta reais no Depósito São José"',
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
                        _LinhaEntendida(
                          icone: Icons.payments,
                          rotulo: 'Valor',
                          valor: _interpretado!.valor != null
                              ? Formatters.moeda(_interpretado!.valor!)
                              : null,
                        ),
                        _LinhaEntendida(
                          icone: Icons.event,
                          rotulo: 'Data',
                          valor: _interpretado!.data != null
                              ? _rotuloData(_interpretado!.data!)
                              : null,
                        ),
                        _LinhaEntendida(
                          icone: _interpretado!.categoria.icone,
                          rotulo: 'Categoria',
                          valor: _interpretado!.categoria.label,
                        ),
                        _LinhaEntendida(
                          icone: Icons.storefront,
                          rotulo: 'Fornecedor',
                          valor: _interpretado!.fornecedorNome,
                        ),
                        _LinhaEntendida(
                          icone: Icons.inventory_2,
                          rotulo: 'Materiais',
                          valor: _interpretado!.itens.isEmpty
                              ? null
                              : _interpretado!.itens
                                  .map((i) => i.resumo)
                                  .join(' · '),
                        ),
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
  final IconData icone;
  final String rotulo;
  final String? valor;

  const _LinhaEntendida({
    required this.icone,
    required this.rotulo,
    this.valor,
  });

  @override
  Widget build(BuildContext context) {
    final entendido = valor != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icone,
              size: 16,
              color: entendido
                  ? AppColors.laranja
                  : AppColors.textoDesabilitado),
          const SizedBox(width: 8),
          SizedBox(
            width: 86,
            child: Text(
              rotulo,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textoSecundario),
            ),
          ),
          Expanded(
            child: Text(
              valor ?? '—',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight:
                        entendido ? FontWeight.w600 : FontWeight.normal,
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
