import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';

/// A transição do app, num lugar só.
///
/// A tela nova entra pela direita **opaca**, deslizando por cima da
/// anterior, que recua um pouco para a esquerda e escurece sob um véu.
/// Nenhuma das duas fica transparente em momento algum.
///
/// Por que não é mais um fade: fade cruzado entre duas telas cheias deixa
/// as duas semitransparentes no meio do caminho, e aí se enxerga uma
/// através da outra — o "tudo por cima de tudo" que parecia sujeira na
/// tela. Deslizar placa sobre placa, com sombra na borda e sombra de
/// profundidade embaixo, é o mesmo gesto de um material sendo assentado
/// sobre o outro: combina com obra e não embaralha nada.
const Duration _duracaoEntrada = Duration(milliseconds: 300);
const Duration _duracaoSaida = Duration(milliseconds: 250);

/// Quanto a tela de baixo recua enquanto a de cima entra. O deslocamento
/// pequeno dá profundidade sem parecer que duas telas estão brigando.
const double _recuo = 0.22;

/// Opacidade do véu sobre a tela que ficou embaixo.
const double _veu = 0.42;

Widget _construirTransicao(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final entra = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final sai = CurvedAnimation(
    parent: secondaryAnimation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  return SlideTransition(
    // Entrada: da borda direita até o lugar.
    position: Tween(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(entra),
    child: SlideTransition(
      // Saída: recua para a esquerda quando outra tela cobre esta.
      position: Tween(
        begin: Offset.zero,
        end: const Offset(-_recuo, 0),
      ).animate(sai),
      child: _PlacaDeslizante(entra: entra, veu: sai, child: child),
    ),
  );
}

/// A tela como uma placa: fundo opaco, sombra na borda que entra e véu
/// quando fica embaixo.
class _PlacaDeslizante extends StatelessWidget {
  final Animation<double> entra;
  final Animation<double> veu;
  final Widget child;

  const _PlacaDeslizante({
    required this.entra,
    required this.veu,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // O fundo garante que nada de trás apareça mesmo se a tela filha
      // demorar um quadro para pintar o próprio fundo.
      decoration: const BoxDecoration(
        color: AppColors.fundo,
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(-6, 0),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          // Véu sobre a tela de baixo. Fora da transição a opacidade é
          // zero, então não custa nada nem intercepta toque.
          IgnorePointer(
            child: FadeTransition(
              opacity: Tween(begin: 0.0, end: _veu).animate(veu),
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

/// Troca de área do app — splash, login, cadastro e a casa de cada perfil.
///
/// Aqui não existe "entrar mais fundo": uma área substitui a outra. O
/// deslize lateral ficaria estranho porque a tela que sai e a que entra
/// andariam para o mesmo lado ao mesmo tempo.
///
/// O fundo da tela nova é pintado opaco já no primeiro quadro e só o
/// conteúdo aparece. Assim a tela anterior some de vista na hora — nunca
/// se vê uma através da outra — e o que se percebe é o conteúdo assentando
/// no lugar.
Widget _construirTransicaoRaiz(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final entra = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return ColoredBox(
    color: AppColors.fundo,
    child: FadeTransition(
      opacity: entra,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(entra),
        child: child,
      ),
    ),
  );
}

/// Página do go_router para telas abertas *sobre* outra — o caminho para
/// dentro da obra. Desliza da direita.
CustomTransitionPage<void> paginaSuave(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: _duracaoEntrada,
      reverseTransitionDuration: _duracaoSaida,
      transitionsBuilder: _construirTransicao,
    );

/// Página do go_router para troca de área. Ver [_construirTransicaoRaiz].
CustomTransitionPage<void> paginaRaiz(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: _duracaoEntrada,
      reverseTransitionDuration: _duracaoSaida,
      transitionsBuilder: _construirTransicaoRaiz,
    );

/// Mesma transição para `Navigator.push` — telas abertas fora do router.
Route<T> rotaSuave<T>(Widget destino) => PageRouteBuilder<T>(
      transitionDuration: _duracaoEntrada,
      reverseTransitionDuration: _duracaoSaida,
      pageBuilder: (_, __, ___) => destino,
      transitionsBuilder: _construirTransicao,
    );
