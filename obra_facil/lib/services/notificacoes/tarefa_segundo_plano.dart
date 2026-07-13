import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';

import '../../firebase_options.dart';
import '../../models/models.dart';
import '../auth_service.dart';
import '../firestore_service.dart';
import 'analisador_notificacoes.dart';
import 'notificacao_service.dart';
import 'preferencias_notificacao.dart';

const _nomeTarefa = 'br.com.obrafacil.verificador';

/// Ponto de entrada do WorkManager — roda num isolate próprio, com o app
/// fechado, a cada ~15 minutos. É o que permite o dono receber "novo
/// lançamento para aprovar" e o mestre receber "aprovado!" sem servidor.
@pragma('vm:entry-point')
void notificacoesCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {
      // já estava inicializado neste isolate
    }
    try {
      await _verificar();
    } catch (_) {
      // silêncio: tenta de novo no próximo ciclo
    }
    return true;
  });
}

Future<void> _verificar() async {
  final prefs = await PreferenciasNotificacao.carregar();
  if (!prefs.verificadorNecessario) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final usuario = await AuthService().carregarPerfil(user.uid);
  if (usuario == null) return;

  final db = FirestoreService();
  final obras = await db.obrasDoUsuario(usuario.id).first;
  if (obras.isEmpty) return;

  final lancamentos = <String, List<LancamentoModel>>{};
  final estoque = <String, List<EstoqueItemModel>>{};
  final movimentos = <String, List<MovimentoEstoqueModel>>{};
  final diario = <String, List<DiarioEntradaModel>>{};
  final cronograma = <String, List<CronogramaFaseModel>>{};
  for (final obra in obras.take(10)) {
    lancamentos[obra.id] = await db.lancamentos(obra.id).first;
    estoque[obra.id] = await db.estoque(obra.id).first;
    movimentos[obra.id] = await db.movimentos(obra.id).first;
    diario[obra.id] = await db.diario(obra.id).first;
    cronograma[obra.id] = await db.cronograma(obra.id).first;
  }

  final ultima = await PreferenciasNotificacao.ultimaChecagem();
  final jaNotificadas = await PreferenciasNotificacao.chavesNotificadas();

  var novas = AnalisadorNotificacoes.analisar(
    usuario: usuario,
    obras: obras,
    lancamentosPorObra: lancamentos,
    estoquePorObra: estoque,
    movimentosPorObra: movimentos,
    diarioPorObra: diario,
    cronogramaPorObra: cronograma,
    ultimaChecagem: ultima,
    chavesJaNotificadas: jaNotificadas,
  );
  if (!prefs.aprovacoes) {
    novas = novas.where((n) => n.canal != 'aprovacoes').toList();
  }
  if (!prefs.alertas) {
    novas = novas.where((n) => n.canal != 'alertas').toList();
  }

  await NotificacaoService.inicializar();
  // no máximo 5 por ciclo para não virar spam
  for (final n in novas.take(5)) {
    await NotificacaoService.mostrar(
        id: n.id, titulo: n.titulo, corpo: n.corpo, canal: n.canal);
  }
  await PreferenciasNotificacao.registrarChaves(
      novas.map((n) => n.chave).toSet());
  await PreferenciasNotificacao.marcarChecagem(DateTime.now());
}

/// Liga/desliga o verificador periódico.
abstract class VerificadorSegundoPlano {
  static Future<void> registrar() async {
    await Workmanager().initialize(notificacoesCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      'verificador_obra',
      _nomeTarefa,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> cancelar() =>
      Workmanager().cancelByUniqueName('verificador_obra');
}

/// Configuração única após o login: permissão, lembretes e verificador.
abstract class NotificacaoBootstrap {
  static bool _feito = false;

  static Future<void> aplicar() async {
    if (_feito) return;
    _feito = true;
    try {
      await NotificacaoService.inicializar();
      await NotificacaoService.pedirPermissao();
      final prefs = await PreferenciasNotificacao.carregar();
      await NotificacaoService.aplicarLembretes(prefs);
      if (prefs.verificadorNecessario) {
        await VerificadorSegundoPlano.registrar();
      }
    } catch (_) {
      // notificações nunca podem derrubar o app
    }
  }
}
