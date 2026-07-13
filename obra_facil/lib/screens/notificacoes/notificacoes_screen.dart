import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/notificacoes/notificacao_service.dart';
import '../../services/notificacoes/preferencias_notificacao.dart';
import '../../services/notificacoes/tarefa_segundo_plano.dart';
import '../../widgets/carregando_obra.dart';

/// Preferências de notificação: o que avisar e em que horário.
class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({super.key});

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  PreferenciasNotificacao? _prefs;

  @override
  void initState() {
    super.initState();
    PreferenciasNotificacao.carregar().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  Future<void> _aplicar() async {
    final p = _prefs!;
    await p.salvar();
    await NotificacaoService.aplicarLembretes(p);
    if (p.verificadorNecessario) {
      await VerificadorSegundoPlano.registrar();
    } else {
      await VerificadorSegundoPlano.cancelar();
    }
  }

  Future<void> _escolherHora(
      int hora, int minuto, void Function(TimeOfDay) aoEscolher) async {
    final escolhida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hora, minute: minuto),
    );
    if (escolhida != null) {
      setState(() => aoEscolher(escolhida));
      await _aplicar();
    }
  }

  String _horaTexto(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = _prefs;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: p == null
          ? const CarregandoObra(mensagem: 'Carregando preferências…')
          : ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
              children: [
                const _TituloSecao('Lembretes da rotina'),
                SwitchListTile(
                  value: p.lembreteDiario,
                  onChanged: (v) async {
                    setState(() => p.lembreteDiario = v);
                    await _aplicar();
                  },
                  activeTrackColor: AppColors.laranja,
                  title: const Text('Registrar o dia no canteiro 📝'),
                  subtitle:
                      Text('Todo dia às ${_horaTexto(p.lembreteDiarioHora, p.lembreteDiarioMinuto)}'),
                ),
                if (p.lembreteDiario)
                  _LinhaHora(
                    hora: _horaTexto(
                        p.lembreteDiarioHora, p.lembreteDiarioMinuto),
                    onTap: () => _escolherHora(
                      p.lembreteDiarioHora,
                      p.lembreteDiarioMinuto,
                      (t) {
                        p.lembreteDiarioHora = t.hour;
                        p.lembreteDiarioMinuto = t.minute;
                      },
                    ),
                  ),
                SwitchListTile(
                  value: p.resumoMatinal,
                  onChanged: (v) async {
                    setState(() => p.resumoMatinal = v);
                    await _aplicar();
                  },
                  activeTrackColor: AppColors.laranja,
                  title: const Text('Bom dia da obra ☀️'),
                  subtitle: Text(
                      'Todo dia às ${_horaTexto(p.resumoMatinalHora, p.resumoMatinalMinuto)}'),
                ),
                if (p.resumoMatinal)
                  _LinhaHora(
                    hora:
                        _horaTexto(p.resumoMatinalHora, p.resumoMatinalMinuto),
                    onTap: () => _escolherHora(
                      p.resumoMatinalHora,
                      p.resumoMatinalMinuto,
                      (t) {
                        p.resumoMatinalHora = t.hour;
                        p.resumoMatinalMinuto = t.minute;
                      },
                    ),
                  ),
                SwitchListTile(
                  value: p.relatorioSemanal,
                  onChanged: (v) async {
                    setState(() => p.relatorioSemanal = v);
                    await _aplicar();
                  },
                  activeTrackColor: AppColors.laranja,
                  title: const Text('Relatório semanal 📊'),
                  subtitle: Text(
                      'Toda sexta às ${_horaTexto(p.relatorioSemanalHora, p.relatorioSemanalMinuto)}'),
                ),
                if (p.relatorioSemanal)
                  _LinhaHora(
                    hora: _horaTexto(
                        p.relatorioSemanalHora, p.relatorioSemanalMinuto),
                    onTap: () => _escolherHora(
                      p.relatorioSemanalHora,
                      p.relatorioSemanalMinuto,
                      (t) {
                        p.relatorioSemanalHora = t.hour;
                        p.relatorioSemanalMinuto = t.minute;
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                const _TituloSecao('Avisos da obra (a cada ~15 min)'),
                SwitchListTile(
                  value: p.aprovacoes,
                  onChanged: (v) async {
                    setState(() => p.aprovacoes = v);
                    await _aplicar();
                  },
                  activeTrackColor: AppColors.laranja,
                  title: const Text('Aprovações 🔔'),
                  subtitle: const Text(
                      'Dono: novos lançamentos p/ aprovar · Mestre: aprovado/rejeitado'),
                ),
                SwitchListTile(
                  value: p.alertas,
                  onChanged: (v) async {
                    setState(() => p.alertas = v);
                    await _aplicar();
                  },
                  activeTrackColor: AppColors.laranja,
                  title: const Text('Alertas inteligentes 📦💰🚧'),
                  subtitle: const Text(
                      'Estoque no fim, material acabando, orçamento em 90%, fase atrasada'),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => NotificacaoService.mostrar(
                    id: 1,
                    canal: 'lembretes',
                    titulo: '👷 Notificação de teste',
                    corpo:
                        'É assim que os avisos da obra vão chegar. Tudo certo!',
                  ),
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Testar notificação agora'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Os avisos de aprovação e os alertas são verificados pelo '
                  'Android em segundo plano (~15 min), mesmo com o app '
                  'fechado — sem servidor e sem custo.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textoDesabilitado),
                ),
              ],
            ),
    );
  }
}

class _TituloSecao extends StatelessWidget {
  final String texto;

  const _TituloSecao(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.laranja,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _LinhaHora extends StatelessWidget {
  final String hora;
  final VoidCallback onTap;

  const _LinhaHora({required this.hora, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: const Icon(Icons.schedule,
              size: 16, color: AppColors.amareloCapacete),
          label: Text('Mudar horário ($hora)'),
          onPressed: onTap,
        ),
      ),
    );
  }
}
