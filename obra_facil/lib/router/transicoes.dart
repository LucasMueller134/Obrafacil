import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A transição do app, num lugar só.
///
/// A tela nova sobe com fade + zoom sutil; a que fica embaixo encolhe e
/// escurece levemente, como uma pilha de camadas. Antes isso vivia só no
/// router, então qualquer `Navigator.push` solto caía na transição padrão
/// do Android e a tela parecia pular. Aqui as duas formas de navegar —
/// rota do go_router e push imperativo — usam a mesma animação.
const Duration _duracaoEntrada = Duration(milliseconds: 340);
const Duration _duracaoSaida = Duration(milliseconds: 280);

Widget _construirTransicao(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final entrada =
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
  final saida =
      CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut);
  return FadeTransition(
    opacity: entrada,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(entrada),
      child: ScaleTransition(
        scale: Tween(begin: 0.985, end: 1.0).animate(entrada),
        child: ScaleTransition(
          scale: Tween(begin: 1.0, end: 0.97).animate(saida),
          child: FadeTransition(
            opacity: Tween(begin: 1.0, end: 0.85).animate(saida),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// Página do go_router com a transição padrão do app.
CustomTransitionPage<void> paginaSuave(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: _duracaoEntrada,
      reverseTransitionDuration: _duracaoSaida,
      transitionsBuilder: _construirTransicao,
    );

/// Mesma transição para `Navigator.push` — telas abertas fora do router.
Route<T> rotaSuave<T>(Widget destino) => PageRouteBuilder<T>(
      transitionDuration: _duracaoEntrada,
      reverseTransitionDuration: _duracaoSaida,
      pageBuilder: (_, __, ___) => destino,
      transitionsBuilder: _construirTransicao,
    );
