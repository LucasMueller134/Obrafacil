import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'preferencias_notificacao.dart';

/// Notificações locais do app (fora do app, na bandeja do Android):
/// lembretes agendados em horários fixos e avisos imediatos do verificador.
abstract class NotificacaoService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _inicializado = false;

  static const _laranja = Color(0xFFF97316);

  // ids reservados dos lembretes agendados
  static const _idDiario = 9001;
  static const _idMatinal = 9002;
  static const _idSemanal = 9003;

  static Future<void> inicializar() async {
    if (_inicializado) return;
    tzdata.initializeTimeZones();
    try {
      final nome = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(nome));
    } catch (_) {
      // mantém o fuso padrão se o aparelho não informar
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _inicializado = true;
  }

  static Future<void> pedirPermissao() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static NotificationDetails _detalhes(String canal) {
    const canais = {
      'lembretes': ('Lembretes', 'Lembretes diários e semanais da obra'),
      'aprovacoes': ('Aprovações', 'Fluxo de aprovação entre dono e mestre'),
      'alertas': ('Alertas da obra', 'Estoque, orçamento e cronograma'),
    };
    final (nome, descricao) = canais[canal] ?? canais['alertas']!;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        canal,
        nome,
        channelDescription: descricao,
        importance: Importance.high,
        priority: Priority.high,
        color: _laranja,
      ),
    );
  }

  static Future<void> mostrar({
    required int id,
    required String titulo,
    required String corpo,
    String canal = 'alertas',
  }) async {
    await inicializar();
    await _plugin.show(id, titulo, corpo, _detalhes(canal));
  }

  /// (Re)agenda os lembretes fixos conforme as preferências.
  static Future<void> aplicarLembretes(PreferenciasNotificacao prefs) async {
    await inicializar();
    await _plugin.cancel(_idDiario);
    await _plugin.cancel(_idMatinal);
    await _plugin.cancel(_idSemanal);

    if (prefs.lembreteDiario) {
      await _agendar(
        id: _idDiario,
        hora: prefs.lembreteDiarioHora,
        minuto: prefs.lembreteDiarioMinuto,
        titulo: '📝 Como foi o dia no canteiro?',
        corpo: 'Registre o progresso de hoje no diário — leva 1 minuto e '
            'melhora as previsões da obra.',
      );
    }
    if (prefs.resumoMatinal) {
      await _agendar(
        id: _idMatinal,
        hora: prefs.resumoMatinalHora,
        minuto: prefs.resumoMatinalMinuto,
        titulo: '☀️ Bora pra obra!',
        corpo: 'Abra o ObraFácil e veja o panorama: gastos, estoque e o que '
            'precisa de atenção hoje.',
      );
    }
    if (prefs.relatorioSemanal) {
      await _agendar(
        id: _idSemanal,
        hora: prefs.relatorioSemanalHora,
        minuto: prefs.relatorioSemanalMinuto,
        diaDaSemana: DateTime.friday,
        titulo: '📊 Sexta é dia de fechar a semana',
        corpo: 'Seu relatório semanal está pronto no app — gere e '
            'compartilhe com o cliente.',
      );
    }
  }

  static Future<void> _agendar({
    required int id,
    required int hora,
    required int minuto,
    required String titulo,
    required String corpo,
    int? diaDaSemana,
  }) async {
    final agora = tz.TZDateTime.now(tz.local);
    var alvo = tz.TZDateTime(
        tz.local, agora.year, agora.month, agora.day, hora, minuto);
    while (!alvo.isAfter(agora) ||
        (diaDaSemana != null && alvo.weekday != diaDaSemana)) {
      alvo = alvo.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id,
      titulo,
      corpo,
      alvo,
      _detalhes('lembretes'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: diaDaSemana != null
          ? DateTimeComponents.dayOfWeekAndTime
          : DateTimeComponents.time,
    );
  }
}
