import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/cadastro_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/verificar_email_screen.dart';
import '../screens/cliente/cliente_obra_screen.dart';
import '../screens/cliente/cliente_obras_screen.dart';
import '../screens/cronograma/cronograma_screen.dart';
import '../screens/diario/diario_screen.dart';
import '../screens/estoque/estoque_screen.dart';
import '../screens/fornecedores/fornecedores_screen.dart';
import '../screens/galeria/galeria_screen.dart';
import '../screens/lancamentos/lancamentos_screen.dart';
import '../screens/lancamentos/novo_lancamento_screen.dart';
import '../screens/notificacoes/notificacoes_screen.dart';
import '../screens/obras/nova_obra_screen.dart';
import '../screens/obras/obra_detalhe_screen.dart';
import '../screens/obras/obras_screen.dart';
import '../screens/relatorios/relatorio_screen.dart';
import '../screens/splash_screen.dart';
import 'transicoes.dart';

/// Transição padrão entre telas — definida em router/transicoes.dart para
/// que os `Navigator.push` fora do router usem exatamente a mesma.
CustomTransitionPage<void> _pagina(GoRouterState state, Widget child) =>
    paginaSuave(state, child);

/// Rotas do app. O redirect centraliza a regra de acesso: deslogado só vê
/// login/cadastro; logado nunca volta para elas; e cliente vive na área
/// dele, sem caminho para as telas de dinheiro da equipe.
GoRouter criarRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      final local = state.matchedLocation;
      final rotaPublica = local == '/login' || local == '/cadastro';

      if (auth.inicializando) return local == '/splash' ? null : '/splash';
      if (!auth.logado) return rotaPublica ? null : '/login';

      // Cliente é gente de fora: só entra com o e-mail confirmado.
      if (auth.ehCliente && !auth.emailVerificado) {
        return local == '/verificar-email' ? null : '/verificar-email';
      }
      final inicio = auth.ehCliente ? '/cliente' : '/obras';
      if (local == '/verificar-email') return inicio;

      // Cada perfil na sua área — inclusive se alguém digitar a rota.
      if (auth.ehCliente && !local.startsWith('/cliente')) return '/cliente';
      if (!auth.ehCliente && local.startsWith('/cliente')) return '/obras';

      if (rotaPublica || local == '/splash') return inicio;
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
        path: '/verificar-email',
        pageBuilder: (_, state) =>
            _pagina(state, const VerificarEmailScreen()),
      ),
      // Área do cliente: acompanha a obra, sem nenhuma tela de dinheiro.
      GoRoute(
        path: '/cliente',
        pageBuilder: (_, state) =>
            _pagina(state, const ClienteObrasScreen()),
        routes: [
          GoRoute(
            path: ':obraId',
            pageBuilder: (_, state) => _pagina(
              state,
              ClienteObraScreen(obraId: state.pathParameters['obraId']!),
            ),
          ),
        ],
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
      GoRoute(
        path: '/notificacoes',
        pageBuilder: (_, state) =>
            _pagina(state, const NotificacoesScreen()),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Rota não encontrada: ${state.uri}')),
    ),
  );
}
