import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/cadastro_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/cronograma/cronograma_screen.dart';
import '../screens/diario/diario_screen.dart';
import '../screens/estoque/estoque_screen.dart';
import '../screens/fornecedores/fornecedores_screen.dart';
import '../screens/galeria/galeria_screen.dart';
import '../screens/lancamentos/lancamentos_screen.dart';
import '../screens/lancamentos/novo_lancamento_screen.dart';
import '../screens/obras/nova_obra_screen.dart';
import '../screens/obras/obra_detalhe_screen.dart';
import '../screens/obras/obras_screen.dart';
import '../screens/relatorios/relatorio_screen.dart';
import '../screens/splash_screen.dart';

/// Transição padrão entre telas: fade + leve deslize lateral.
CustomTransitionPage<void> _pagina(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, _, child) {
        final curva =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curva,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(curva),
            child: child,
          ),
        );
      },
    );

/// Rotas do app. O redirect centraliza a regra de acesso:
/// deslogado só vê login/cadastro; logado nunca volta para elas.
GoRouter criarRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      final local = state.matchedLocation;
      final rotaPublica = local == '/login' || local == '/cadastro';

      if (auth.inicializando) return local == '/splash' ? null : '/splash';
      if (!auth.logado) return rotaPublica ? null : '/login';
      if (rotaPublica || local == '/splash') return '/obras';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, state) => _pagina(state, const SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _pagina(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/cadastro',
        pageBuilder: (_, state) => _pagina(state, const CadastroScreen()),
      ),
      GoRoute(
        path: '/obras',
        pageBuilder: (_, state) => _pagina(state, const ObrasScreen()),
        routes: [
          GoRoute(
            path: 'nova',
            pageBuilder: (_, state) => _pagina(state, const NovaObraScreen()),
          ),
          GoRoute(
            path: ':obraId',
            pageBuilder: (_, state) => _pagina(
              state,
              ObraDetalheScreen(obraId: state.pathParameters['obraId']!),
            ),
            routes: [
              GoRoute(
                path: 'lancamentos',
                pageBuilder: (_, state) => _pagina(
                  state,
                  LancamentosScreen(obraId: state.pathParameters['obraId']!),
                ),
                routes: [
                  GoRoute(
                    path: 'novo',
                    pageBuilder: (_, state) => _pagina(
                      state,
                      NovoLancamentoScreen(
                          obraId: state.pathParameters['obraId']!),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'estoque',
                pageBuilder: (_, state) => _pagina(
                  state,
                  EstoqueScreen(obraId: state.pathParameters['obraId']!),
                ),
              ),
              GoRoute(
                path: 'diario',
                pageBuilder: (_, state) => _pagina(
                  state,
                  DiarioScreen(obraId: state.pathParameters['obraId']!),
                ),
              ),
              GoRoute(
                path: 'cronograma',
                pageBuilder: (_, state) => _pagina(
                  state,
                  CronogramaScreen(obraId: state.pathParameters['obraId']!),
                ),
              ),
              GoRoute(
                path: 'galeria',
                pageBuilder: (_, state) => _pagina(
                  state,
                  GaleriaScreen(obraId: state.pathParameters['obraId']!),
                ),
              ),
              GoRoute(
                path: 'relatorio',
                pageBuilder: (_, state) => _pagina(
                  state,
                  RelatorioScreen(obraId: state.pathParameters['obraId']!),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/fornecedores',
        pageBuilder: (_, state) =>
            _pagina(state, const FornecedoresScreen()),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Rota não encontrada: ${state.uri}')),
    ),
  );
}
