import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../widgets/tres_d/cena_obra_3d.dart';

/// Abertura do app: a maquete 3D do canteiro girando.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _entrada = CurvedAnimation(
    parent: _controle,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _LuzDeFundo(),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                Expanded(
                  flex: 10,
                  child: FadeTransition(
                    opacity: _entrada,
                    child: ScaleTransition(
                      scale:
                          Tween(begin: 0.86, end: 1.0).animate(_entrada),
                      child: const CenaObraTresD(segundosPorVolta: 22),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeTransition(
                  opacity: _entrada,
                  child: Column(
                    children: [
                      Text(
                        AppConstants.appName,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          AppConstants.slogan,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppColors.textoSecundario,
                                height: 1.5,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                const _BarraCarregando(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Brilho quente atrás da maquete — dá profundidade ao fundo escuro sem
/// desenhar mais nada na tela.
class _LuzDeFundo extends StatelessWidget {
  const _LuzDeFundo();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.35),
            radius: 0.95,
            colors: [
              AppColors.laranja.withValues(alpha: 0.16),
              AppColors.laranja.withValues(alpha: 0.04),
              AppColors.fundo,
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Fio de progresso indeterminado, no lugar de um spinner: mais discreto
/// e não disputa atenção com a maquete.
class _BarraCarregando extends StatefulWidget {
  const _BarraCarregando();

  @override
  State<_BarraCarregando> createState() => _BarraCarregandoState();
}

class _BarraCarregandoState extends State<_BarraCarregando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: AnimatedBuilder(
          animation: _controle,
          builder: (_, __) => LinearProgressIndicator(
            value: null,
            backgroundColor: AppColors.superficieAlta,
            valueColor:
                const AlwaysStoppedAnimation(AppColors.laranja),
          ),
        ),
      ),
    );
  }
}
