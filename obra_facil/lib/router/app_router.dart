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
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/cadastro',
        builder: (_, __) => const CadastroScreen(),
      ),
      GoRoute(
        path: '/obras',
        builder: (_, __) => const ObrasScreen(),
        routes: [
          GoRoute(
            path: 'nova',
            builder: (_, __) => const NovaObraScreen(),
          ),
          GoRoute(
            path: ':obraId',
            builder: (_, state) =>
                ObraDetalheScreen(obraId: state.pathParameters['obraId']!),
            routes: [
              GoRoute(
                path: 'lancamentos',
                builder: (_, state) => LancamentosScreen(
                    obraId: state.pathParameters['obraId']!),
                routes: [
                  GoRoute(
                    path: 'novo',
                    builder: (_, state) => NovoLancamentoScreen(
                        obraId: state.pathParameters['obraId']!),
                  ),
                ],
              ),
              GoRoute(
                path: 'estoque',
                builder: (_, state) =>
                    EstoqueScreen(obraId: state.pathParameters['obraId']!),
              ),
              GoRoute(
                path: 'diario',
                builder: (_, state) =>
                    DiarioScreen(obraId: state.pathParameters['obraId']!),
              ),
              GoRoute(
                path: 'cronograma',
                builder: (_, state) =>
                    CronogramaScreen(obraId: state.pathParameters['obraId']!),
              ),
              GoRoute(
                path: 'galeria',
                builder: (_, state) =>
                    GaleriaScreen(obraId: state.pathParameters['obraId']!),
              ),
              GoRoute(
                path: 'relatorio',
                builder: (_, state) =>
                    RelatorioScreen(obraId: state.pathParameters['obraId']!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/fornecedores',
        builder: (_, __) => const FornecedoresScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Rota não encontrada: ${state.uri}')),
    ),
  );
}
