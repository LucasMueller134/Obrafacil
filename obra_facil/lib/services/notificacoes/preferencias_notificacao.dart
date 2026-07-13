import 'package:shared_preferences/shared_preferences.dart';

/// Preferências de notificação do usuário, guardadas no aparelho.
class PreferenciasNotificacao {
  bool lembreteDiario;
  int lembreteDiarioHora;
  int lembreteDiarioMinuto;

  bool resumoMatinal;
  int resumoMatinalHora;
  int resumoMatinalMinuto;

  bool relatorioSemanal; // sexta-feira
  int relatorioSemanalHora;
  int relatorioSemanalMinuto;

  bool aprovacoes; // dono ↔ mestre (verificador em segundo plano)
  bool alertas; // estoque, orçamento, fases

  PreferenciasNotificacao({
    this.lembreteDiario = true,
    this.lembreteDiarioHora = 17,
    this.lembreteDiarioMinuto = 30,
    this.resumoMatinal = true,
    this.resumoMatinalHora = 7,
    this.resumoMatinalMinuto = 30,
    this.relatorioSemanal = true,
    this.relatorioSemanalHora = 16,
    this.relatorioSemanalMinuto = 30,
    this.aprovacoes = true,
    this.alertas = true,
  });

  bool get verificadorNecessario => aprovacoes || alertas;

  static Future<PreferenciasNotificacao> carregar() async {
    final p = await SharedPreferences.getInstance();
    return PreferenciasNotificacao(
      lembreteDiario: p.getBool('nf_diario') ?? true,
      lembreteDiarioHora: p.getInt('nf_diario_h') ?? 17,
      lembreteDiarioMinuto: p.getInt('nf_diario_m') ?? 30,
      resumoMatinal: p.getBool('nf_matinal') ?? true,
      resumoMatinalHora: p.getInt('nf_matinal_h') ?? 7,
      resumoMatinalMinuto: p.getInt('nf_matinal_m') ?? 30,
      relatorioSemanal: p.getBool('nf_semanal') ?? true,
      relatorioSemanalHora: p.getInt('nf_semanal_h') ?? 16,
      relatorioSemanalMinuto: p.getInt('nf_semanal_m') ?? 30,
      aprovacoes: p.getBool('nf_aprovacoes') ?? true,
      alertas: p.getBool('nf_alertas') ?? true,
    );
  }

  Future<void> salvar() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('nf_diario', lembreteDiario);
    await p.setInt('nf_diario_h', lembreteDiarioHora);
    await p.setInt('nf_diario_m', lembreteDiarioMinuto);
    await p.setBool('nf_matinal', resumoMatinal);
    await p.setInt('nf_matinal_h', resumoMatinalHora);
    await p.setInt('nf_matinal_m', resumoMatinalMinuto);
    await p.setBool('nf_semanal', relatorioSemanal);
    await p.setInt('nf_semanal_h', relatorioSemanalHora);
    await p.setInt('nf_semanal_m', relatorioSemanalMinuto);
    await p.setBool('nf_aprovacoes', aprovacoes);
    await p.setBool('nf_alertas', alertas);
  }

  // ---- Estado do verificador em segundo plano (dedupe + última checagem)

  static Future<DateTime> ultimaChecagem() async {
    final p = await SharedPreferences.getInstance();
    final iso = p.getString('nf_ultima_checagem');
    return DateTime.tryParse(iso ?? '') ??
        DateTime.now().subtract(const Duration(hours: 6));
  }

  static Future<void> marcarChecagem(DateTime quando) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('nf_ultima_checagem', quando.toIso8601String());
  }

  /// Chaves já notificadas (zera a cada dia para os alertas diários).
  static Future<Set<String>> chavesNotificadas() async {
    final p = await SharedPreferences.getInstance();
    final hoje = DateTime.now();
    final dia = '${hoje.year}-${hoje.month}-${hoje.day}';
    if (p.getString('nf_chaves_dia') != dia) {
      await p.setString('nf_chaves_dia', dia);
      await p.setStringList('nf_chaves', []);
      return {};
    }
    return (p.getStringList('nf_chaves') ?? []).toSet();
  }

  static Future<void> registrarChaves(Set<String> chaves) async {
    final p = await SharedPreferences.getInstance();
    final atuais = (p.getStringList('nf_chaves') ?? []).toSet()
      ..addAll(chaves);
    // limita o histórico para não crescer sem fim
    await p.setStringList('nf_chaves', atuais.take(300).toList());
  }
}
