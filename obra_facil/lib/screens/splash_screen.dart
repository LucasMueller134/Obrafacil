import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../design/design.dart';

/// Abertura do app, enquanto o login responde. Continua a splash nativa
/// sem pulo: o mesmo papel de fundo e o ícone da planta no mesmo lugar (o
/// centro da janela, em 240 dp, como a splash do Android 12). Embaixo
/// entram o nome, o slogan e o indicador de carregando.
///
/// A maquete 3D girando que ficava aqui saiu: custava o quadro inteiro do
/// celular justo na hora em que o app ainda está abrindo, e a maquete
/// agora mora na central da obra.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  /// Lado do ícone da splash nativa do Android 12 (o círculo visível tem
  /// 160 dp; o desenho fica dentro dele).
  static const double ladoIcone = 240;

  @override
  Widget build(BuildContext context) =>
      TemaPrancheta(child: Builder(builder: _tela));

  Widget _tela(BuildContext context) {
    final c = context.cores;
    final icone =
        c.ehEscuro ? 'assets/icone/splash_escuro.png' : 'assets/icone/splash.png';
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Image.asset(
              icone,
              width: ladoIcone,
              height: ladoIcone,
              excludeFromSemantics: true,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            // Logo abaixo do desenho do ícone: no quadrado de 240 dp, o
            // desenho vai de 30% a 70% da altura (uns 94 dp no meio).
            top: MediaQuery.sizeOf(context).height / 2 +
                ladoIcone * 0.2 +
                Espaco.e24,
            child: Align(
              alignment: Alignment.topCenter,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: context.duracao(Movimento.lento),
                curve: Movimento.entrar,
                builder: (context, v, filho) => Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, (1 - v) * Espaco.e8),
                    child: filho,
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: Espaco.e32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          AppConstants.appName,
                          textAlign: TextAlign.center,
                          style:
                              Tipografia.tituloTela.copyWith(color: c.grafite),
                        ),
                      ),
                      const SizedBox(height: Espaco.e4),
                      Text(
                        AppConstants.slogan,
                        textAlign: TextAlign.center,
                        style: Tipografia.apoio.copyWith(color: c.grafite2),
                      ),
                      const SizedBox(height: Espaco.e24),
                      Semantics(
                        label: 'Abrindo o Obra na Mão',
                        child: const IndicadorCarregando(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
