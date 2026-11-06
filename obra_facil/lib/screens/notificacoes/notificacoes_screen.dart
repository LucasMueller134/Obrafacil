import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../services/notificacoes/notificacao_service.dart';
import '../../services/notificacoes/preferencias_notificacao.dart';
import '../../services/notificacoes/tarefa_segundo_plano.dart';

/// Preferências de notificação: o que avisar e em que horário.
class NotificacoesScreen extends StatelessWidget {
  const NotificacoesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const TemaPrancheta(child: _Notificacoes());
}

class _Notificacoes extends StatefulWidget {
  const _Notificacoes();

  @override
  State<_Notificacoes> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<_Notificacoes> {
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

  /// Liga ou desliga e já aplica (agenda ou cancela os lembretes).
  Future<void> _trocar(void Function() mudar) async {
    unawaited(Tato.leve());
    setState(mudar);
    await _aplicar();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final p = _prefs;
    return Scaffold(
      appBar: AppBar(),
      body: p == null
          ? ListView(
              padding: const EdgeInsets.all(Espaco.margem),
              children: const [
                EsqueletoFolha(
                    linhas: 4, rotuloSemantico: 'Abrindo as preferências'),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e32),
              children: [
                const Rotulo('Configurações'),
                const SizedBox(height: Espaco.e4),
                Semantics(
                  header: true,
                  child: Text('Notificações',
                      style: Tipografia.tituloTela.copyWith(color: c.grafite)),
                ),
                const SizedBox(height: Espaco.e24),
                const LinhaCota(legenda: 'Lembretes da rotina'),
                const SizedBox(height: Espaco.e16),
                Folha(
                  preenchimento: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Interruptor(
                        titulo: 'Registrar o dia no canteiro',
                        apoio: p.lembreteDiario
                            ? 'Todo dia, para escrever o diário'
                            : 'Desligado',
                        valor: p.lembreteDiario,
                        aoMudar: (v) => _trocar(() => p.lembreteDiario = v),
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
                      const _Divisoria(),
                      _Interruptor(
                        titulo: 'Bom dia da obra',
                        apoio: p.resumoMatinal
                            ? 'Todo dia, o resumo da obra'
                            : 'Desligado',
                        valor: p.resumoMatinal,
                        aoMudar: (v) => _trocar(() => p.resumoMatinal = v),
                      ),
                      if (p.resumoMatinal)
                        _LinhaHora(
                          hora: _horaTexto(
                              p.resumoMatinalHora, p.resumoMatinalMinuto),
                          onTap: () => _escolherHora(
                            p.resumoMatinalHora,
                            p.resumoMatinalMinuto,
                            (t) {
                              p.resumoMatinalHora = t.hour;
                              p.resumoMatinalMinuto = t.minute;
                            },
                          ),
                        ),
                      const _Divisoria(),
                      _Interruptor(
                        titulo: 'Relatório semanal',
                        apoio: p.relatorioSemanal
                            ? 'Toda sexta, a análise da semana'
                            : 'Desligado',
                        valor: p.relatorioSemanal,
                        aoMudar: (v) => _trocar(() => p.relatorioSemanal = v),
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
                    ],
                  ),
                ),
                const SizedBox(height: Espaco.e24),
                const LinhaCota(legenda: 'Avisos da obra'),
                const SizedBox(height: Espaco.e16),
                Folha(
                  preenchimento: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Interruptor(
                        titulo: 'Aprovações',
                        apoio: 'Dono: lançamentos novos para aprovar. '
                            'Mestre: aprovado ou recusado.',
                        valor: p.aprovacoes,
                        aoMudar: (v) => _trocar(() => p.aprovacoes = v),
                      ),
                      const _Divisoria(),
                      _Interruptor(
                        titulo: 'Alertas da obra',
                        apoio: 'Estoque no fim, material acabando, orçamento '
                            'em 90% e fase atrasada.',
                        valor: p.alertas,
                        aoMudar: (v) => _trocar(() => p.alertas = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Espaco.e8),
                Text(
                  'Os avisos são conferidos pelo Android em segundo plano, a '
                  'cada 15 minutos mais ou menos, mesmo com o app fechado. '
                  'Sem servidor e sem custo.',
                  style: Tipografia.apoio.copyWith(color: c.grafite2),
                ),
                const SizedBox(height: Espaco.e24),
                BotaoContorno(
                  rotulo: 'Testar notificação agora',
                  icone: Icons.notifications_active_outlined,
                  expandir: true,
                  aoTocar: () => NotificacaoService.mostrar(
                    id: 1,
                    canal: 'lembretes',
                    titulo: '👷 Notificação de teste',
                    corpo:
                        'É assim que os avisos da obra vão chegar. Tudo certo!',
                  ),
                ),
              ],
            ),
    );
  }
}

class _Interruptor extends StatelessWidget {
  const _Interruptor({
    required this.titulo,
    required this.apoio,
    required this.valor,
    required this.aoMudar,
  });

  final String titulo;
  final String apoio;
  final bool valor;
  final ValueChanged<bool> aoMudar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    // O toque precisa de um Material logo acima (a folha é uma caixa).
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        value: valor,
        onChanged: aoMudar,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Espaco.e12, vertical: Espaco.e4),
        title: Text(titulo,
            style: Tipografia.corpoForte.copyWith(color: c.grafite)),
        subtitle:
            Text(apoio, style: Tipografia.apoio.copyWith(color: c.grafite2)),
      ),
    );
  }
}

class _Divisoria extends StatelessWidget {
  const _Divisoria();

  @override
  Widget build(BuildContext context) => Divider(
      height: Traco.fino, thickness: Traco.fino, color: context.cores.grade);
}

class _LinhaHora extends StatelessWidget {
  final String hora;
  final VoidCallback onTap;

  const _LinhaHora({required this.hora, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LinhaLista(
      icone: Icons.schedule,
      titulo: 'Horário',
      apoio: 'Toque para mudar',
      rotuloSemantico: 'Horário: $hora. Toque para mudar.',
      valor: hora,
      margemHorizontal: Espaco.e12,
      aoTocar: onTap,
    );
  }
}
