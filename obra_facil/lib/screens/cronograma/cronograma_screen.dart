import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../design/design.dart';
import '../../design/maquete/maquete.dart';
import '../../models/models.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';

/// O cronograma da obra na linguagem da prancheta: o carimbo com o avanço
/// e a fase atual, a régua da obra inteira e as fases em ordem. Tocar numa
/// fase abre a folha de atualizar o avanço, com botões grandes de 5 em 5
/// (dá para acertar de luva) e "Salvar" com desfazer. É daqui que a
/// maquete da central sabe o que já foi construído.
class CronogramaScreen extends StatelessWidget {
  final String obraId;

  const CronogramaScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) =>
      TemaPrancheta(child: _Cronograma(obraId: obraId));
}

class _Cronograma extends StatefulWidget {
  const _Cronograma({required this.obraId});

  final String obraId;

  @override
  State<_Cronograma> createState() => _CronogramaState();
}

class _CronogramaState extends State<_Cronograma> {
  // Abertas uma vez: o StreamBuilder reassina quando recebe Stream nova.
  late Stream<List<CronogramaFaseModel>> _fases;
  late Stream<ObraModel?> _obra;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  @override
  void didUpdateWidget(_Cronograma antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.obraId != widget.obraId) _abrir();
  }

  void _abrir() {
    final db = context.read<FirestoreService>();
    _fases = db.cronograma(widget.obraId);
    _obra = db.obra(widget.obraId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: StreamBuilder<ObraModel?>(
        stream: _obra,
        builder: (context, obraSnap) =>
            StreamBuilder<List<CronogramaFaseModel>>(
          stream: _fases,
          builder: (context, snap) => AnimatedSwitcher(
            duration: context.duracao(Movimento.medio),
            switchInCurve: Movimento.entrar,
            switchOutCurve: Movimento.sair,
            child: KeyedSubtree(
              key: ValueKey(snap.connectionState == ConnectionState.waiting
                  ? 'carregando'
                  : 'pronto'),
              child: _corpo(context, obraSnap.data, snap),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BarraDeAcao(
        principal: BotaoPrincipal(
          rotulo: 'Adicionar fase',
          icone: Icons.add,
          grande: true,
          expandir: true,
          aoTocar: () => unawaited(_novaFase(context)),
        ),
      ),
    );
  }

  Widget _corpo(
    BuildContext context,
    ObraModel? obra,
    AsyncSnapshot<List<CronogramaFaseModel>> snap,
  ) {
    if (snap.connectionState == ConnectionState.waiting) {
      return ListView(
        padding: const EdgeInsets.all(Espaco.margem),
        children: const [
          EsqueletoFolha(
            linhas: 2,
            comValor: false,
            rotuloSemantico: 'Montando o cronograma',
          ),
          SizedBox(height: Espaco.e16),
          ExcludeSemantics(child: EsqueletoFolha(linhas: 4)),
        ],
      );
    }
    final fases = [...?snap.data]..sort((a, b) => a.ordem.compareTo(b.ordem));
    final progresso = ProgressoMaquete.doCronograma(fases);
    final atual = fases
            .where(
                (f) => f.percentualConcluido > 0 && f.percentualConcluido < 100)
            .firstOrNull ??
        fases.where((f) => f.percentualConcluido < 100).firstOrNull;
    final atrasadas = fases.where((f) => f.atrasada).length;

    return ListView(
      padding: const EdgeInsets.only(top: Espaco.e4, bottom: Espaco.e32),
      children: [
        _NaMargem(
          Carimbo(linhas: [
            [
              CelulaCarimbo(
                rotulo: 'Cronograma',
                conteudo: Semantics(
                  header: true,
                  child: Text(
                    obra?.nome ?? 'Obra',
                    style: Tipografia.tituloTela
                        .copyWith(color: context.cores.grafite),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            if (fases.isNotEmpty)
              [
                CelulaCarimbo(
                  rotulo: 'Avanço',
                  valor: '${progresso.percentualObra}%',
                ),
                CelulaCarimbo(
                  rotulo: 'Fase atual',
                  valor: atual?.nome ?? 'Concluídas',
                  flex: 2,
                ),
              ],
          ]),
        ),
        if (fases.isEmpty && snap.hasError) ...[
          const SizedBox(height: Espaco.e24),
          const _NaMargem(
            AvisoVazio(
              icone: Icons.cloud_off_outlined,
              titulo: 'O cronograma não carregou',
              texto: 'Confira a internet e abra a tela de novo.',
            ),
          ),
        ] else if (fases.isEmpty) ...[
          const SizedBox(height: Espaco.e24),
          const _NaMargem(
            AvisoVazio(
              icone: Icons.view_timeline_outlined,
              titulo: 'Sem cronograma',
              texto: 'Adicione as fases da obra para acompanhar o avanço de '
                  'cada etapa. Com os nomes das fases padrão (Fundação, '
                  'Estrutura, Alvenaria…), a maquete da obra se constrói '
                  'junto.',
            ),
          ),
        ] else ...[
          const SizedBox(height: Espaco.e16),
          _NaMargem(
            ReguaCota(
              valor: progresso.percentualObra / 100,
              rotuloSemantico: 'Avanço da obra',
            ),
          ),
          if (atrasadas > 0) ...[
            const SizedBox(height: Espaco.e16),
            _NaMargem(
              Align(
                alignment: Alignment.centerLeft,
                child: SeloStatus(
                  StatusSelo.aviso,
                  texto: atrasadas == 1
                      ? '1 fase atrasada'
                      : '$atrasadas fases atrasadas',
                ),
              ),
            ),
          ],
          const SizedBox(height: Espaco.e24),
          _NaMargem(
            Semantics(
              header: true,
              container: true,
              child: LinhaCota(
                legenda: fases.length == 1 ? '1 fase' : '${fases.length} fases',
              ),
            ),
          ),
          const SizedBox(height: Espaco.e16),
          _NaMargem(
            Folha(
              preenchimento: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < fases.length; i++)
                    _LinhaFase(
                      numero: i + 1,
                      fase: fases[i],
                      divisoria: i < fases.length - 1,
                      aoTocar: () => _abrirFase(context, fases[i], i + 1),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _abrirFase(BuildContext context, CronogramaFaseModel fase, int numero) {
    final db = context.read<FirestoreService>();
    unawaited(showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FolhaFase(
        fase: fase,
        numero: numero,
        aoSalvar: (percentual) {
          if (percentual == fase.percentualConcluido) return;
          unawaited(db.salvarFase(
            fase.copyWith(percentualConcluido: percentual),
          ));
          unawaited(Tato.confirmar());
          mostrarAviso(
            context,
            '${fase.nome} em $percentual%.',
            aoDesfazer: () => unawaited(db.salvarFase(fase)),
          );
        },
        aoExcluir: () {
          unawaited(db.excluirFase(widget.obraId, fase.id));
          unawaited(Tato.confirmar());
          // Desfazer grava a mesma fase de novo, com o mesmo id.
          mostrarAviso(
            context,
            'Fase "${fase.nome}" excluída.',
            aoDesfazer: () => unawaited(db.salvarFase(fase)),
          );
        },
      ),
    ));
  }

  Future<void> _novaFase(BuildContext context) async {
    final db = context.read<FirestoreService>();
    final fases = await db.cronograma(widget.obraId).first;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormFase(
        obraId: widget.obraId,
        ordem: fases.length,
        nomesUsados: {for (final f in fases) f.nome},
      ),
    );
  }
}

class _NaMargem extends StatelessWidget {
  const _NaMargem(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Espaco.margem),
        child: child,
      );
}

/// Em que pé está a fase, em palavras (nunca só pela cor).
String _situacao(CronogramaFaseModel f) {
  if (f.concluida) return 'Concluída';
  if (f.atrasada) return 'Atrasada · venceu ${Formatters.dataCurta(f.dataFim)}';
  if (f.percentualConcluido > 0 || f.emAndamento) return 'Em andamento';
  if (DateTime.now().isBefore(f.dataInicio)) return 'A começar';
  return 'Não começou';
}

/// Uma fase na lista: número, nome, o avanço à direita, as datas e a
/// situação embaixo e um trilho fino com o que já foi feito.
class _LinhaFase extends StatelessWidget {
  const _LinhaFase({
    required this.numero,
    required this.fase,
    required this.divisoria,
    required this.aoTocar,
  });

  final int numero;
  final CronogramaFaseModel fase;
  final bool divisoria;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final situacao = _situacao(fase);
    // "a" e não seta: a Atkinson não tem o caractere "→".
    final datas = '${Formatters.dataCurta(fase.dataInicio)} a '
        '${Formatters.dataCurta(fase.dataFim)}';
    final IconData? icone = fase.concluida
        ? Icons.check
        : fase.atrasada
            ? Icons.warning_amber_rounded
            : null;
    final corIcone = fase.concluida ? c.ok : c.revisao;

    return AreaPressionavel(
      aoTocar: aoTocar,
      vibrar: true,
      rotuloSemantico: 'Fase $numero, ${fase.nome}, '
          '${fase.percentualConcluido}%, $situacao, $datas',
      dicaSemantica: 'atualizar o avanço',
      construtor: (context, e) => Container(
        decoration: BoxDecoration(
          color: e.pressionado ? c.folhaRebaixada : null,
          border: divisoria
              ? Border(bottom: BorderSide(color: c.grade, width: Traco.fino))
              : null,
        ),
        padding: const EdgeInsets.fromLTRB(
          Espaco.e12,
          Espaco.e16,
          Espaco.e8,
          Espaco.e16,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              child: Text(
                numero.toString().padLeft(2, '0'),
                style: Tipografia.rotulo.copyWith(
                  color: c.grafite2,
                  fontFeatures: Tipografia.tabular,
                  height: 1.6,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ParComValor(
                    esquerda: Text(
                      fase.nome,
                      style: Tipografia.corpoForte.copyWith(color: c.grafite),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    direita: Text(
                      '${fase.percentualConcluido}%',
                      style: Tipografia.subtitulo.copyWith(
                        color: c.grafite,
                        fontFeatures: Tipografia.tabular,
                      ),
                    ),
                  ),
                  const SizedBox(height: Espaco.e8),
                  _Trilho(valor: fase.percentualConcluido / 100),
                  const SizedBox(height: Espaco.e8),
                  Text.rich(
                    TextSpan(children: [
                      if (icone != null)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: Espaco.e4),
                            child: Icon(icone, size: 18, color: corIcone),
                          ),
                        ),
                      TextSpan(text: '$situacao · $datas'),
                    ]),
                    style: Tipografia.apoio.copyWith(color: c.grafite2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Espaco.e4),
            Icon(Icons.chevron_right, color: c.traco),
          ],
        ),
      ),
    );
  }
}

/// Trilho fino do avanço de uma fase: contorno de traço e o feito em
/// grafite (a régua grande fica para a obra inteira).
class _Trilho extends StatelessWidget {
  const _Trilho({required this.valor});

  final double valor;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: c.folhaRebaixada,
        border: Border.all(color: c.traco, width: Traco.fino),
        borderRadius: Raio.cantoPequeno,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: valor.clamp(0.0, 1.0)),
          duration: context.duracao(Movimento.lento),
          curve: Movimento.entrar,
          builder: (context, v, _) => FractionallySizedBox(
            widthFactor: v,
            heightFactor: 1,
            child: ColoredBox(color: c.grafite),
          ),
        ),
      ),
    );
  }
}

/// A folha de atualizar uma fase: o avanço grande no meio, − e + de 5 em
/// 5, o controle deslizante para mudar muito de uma vez, "fase pronta" e
/// "Salvar" no rodapé. Excluir fica embaixo de tudo, com desfazer.
class _FolhaFase extends StatefulWidget {
  const _FolhaFase({
    required this.fase,
    required this.numero,
    required this.aoSalvar,
    required this.aoExcluir,
  });

  final CronogramaFaseModel fase;
  final int numero;
  final ValueChanged<int> aoSalvar;
  final VoidCallback aoExcluir;

  @override
  State<_FolhaFase> createState() => _FolhaFaseState();
}

class _FolhaFaseState extends State<_FolhaFase> {
  late int _percentual = widget.fase.percentualConcluido.clamp(0, 100);

  void _mudar(int novo) {
    final v = novo.clamp(0, 100);
    if (v == _percentual) return;
    setState(() => _percentual = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final fase = widget.fase;
    final mudou = _percentual != fase.percentualConcluido;
    final seguro = MediaQuery.viewPaddingOf(context).bottom;
    final datas = '${Formatters.data(fase.dataInicio)} a '
        '${Formatters.data(fase.dataFim)}';

    return SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Espaco.margem,
          Espaco.e8,
          Espaco.margem,
          Espaco.e16 + seguro,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Rotulo('Fase ${widget.numero.toString().padLeft(2, '0')}'),
            const SizedBox(height: Espaco.e4),
            Text(
              fase.nome,
              style: Tipografia.titulo.copyWith(color: c.grafite),
            ),
            const SizedBox(height: Espaco.e4),
            Text(
              '$datas · ${_situacao(fase)}',
              style: Tipografia.apoio.copyWith(color: c.grafite2),
            ),
            const SizedBox(height: Espaco.e24),
            Row(
              children: [
                BotaoIcone(
                  icone: Icons.remove,
                  rotulo: 'Menos 5%',
                  aoTocar: _percentual > 0
                      ? () => _mudar(_passoAbaixo(_percentual))
                      : null,
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    label: 'Avanço da fase',
                    value: '$_percentual%',
                    child: ExcludeSemantics(
                      child: Text(
                        '$_percentual%',
                        textAlign: TextAlign.center,
                        style: Tipografia.valorHeroi.copyWith(
                          color: c.grafite,
                          fontFeatures: Tipografia.tabular,
                        ),
                      ),
                    ),
                  ),
                ),
                BotaoIcone(
                  icone: Icons.add,
                  rotulo: 'Mais 5%',
                  aoTocar: _percentual < 100
                      ? () => _mudar(_passoAcima(_percentual))
                      : null,
                ),
              ],
            ),
            const SizedBox(height: Espaco.e12),
            Slider(
              value: _percentual.toDouble(),
              max: 100,
              divisions: 20,
              label: '$_percentual%',
              semanticFormatterCallback: (v) => '${v.round()}%',
              onChanged: (v) => _mudar(v.round()),
            ),
            if (_percentual < 100) ...[
              const SizedBox(height: Espaco.e8),
              BotaoContorno(
                rotulo: 'Fase pronta (100%)',
                icone: Icons.check,
                expandir: true,
                aoTocar: () => _mudar(100),
              ),
            ],
            const SizedBox(height: Espaco.e16),
            BotaoPrincipal(
              rotulo: mudou ? 'Salvar $_percentual%' : 'Salvar',
              grande: true,
              expandir: true,
              aoTocar: mudou
                  ? () {
                      Navigator.pop(context);
                      widget.aoSalvar(_percentual);
                    }
                  : null,
            ),
            const SizedBox(height: Espaco.e8),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: c.revisao),
                onPressed: () {
                  Navigator.pop(context);
                  widget.aoExcluir();
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Excluir fase'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Os botões andam de 5 em 5, parando nos múltiplos de 5: de 62%, o
  /// "−" vai para 60% e o "+" para 65% (não para 57% e 67%).
  static int _passoAbaixo(int v) => v % 5 == 0 ? v - 5 : v - v % 5;
  static int _passoAcima(int v) => v % 5 == 0 ? v + 5 : v + 5 - v % 5;
}

class _FormFase extends StatefulWidget {
  final String obraId;
  final int ordem;

  /// Nomes que o cronograma já tem (as fases padrão que faltam viram
  /// sugestão).
  final Set<String> nomesUsados;

  const _FormFase({
    required this.obraId,
    required this.ordem,
    required this.nomesUsados,
  });

  @override
  State<_FormFase> createState() => _FormFaseState();
}

class _FormFaseState extends State<_FormFase> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  DateTime _inicio = DateTime.now();
  DateTime _fim = DateTime.now().add(const Duration(days: 14));
  bool _salvando = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _escolherData(bool inicio) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicio ? _inicio : _fim,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('pt', 'BR'),
    );
    if (escolhida == null) return;
    setState(() {
      if (inicio) {
        _inicio = escolhida;
        if (!_fim.isAfter(_inicio)) {
          _fim = _inicio.add(const Duration(days: 7));
        }
      } else {
        _fim = escolhida;
      }
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    final db = context.read<FirestoreService>();
    await db.salvarFase(CronogramaFaseModel(
      id: '',
      obraId: widget.obraId,
      nome: _nomeCtrl.text.trim(),
      ordem: widget.ordem,
      dataInicio: _inicio,
      dataFim: _fim,
    ));
    unawaited(Tato.confirmar());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final usados = {
      for (final n in widget.nomesUsados) ProgressoMaquete.indiceDaFase(n),
    };
    final sugestoes = [
      for (var i = 0; i < AppConstants.fasesPadrao.length; i++)
        if (!usados.contains(i)) AppConstants.fasesPadrao[i],
    ];
    return Padding(
      padding: EdgeInsets.only(
        left: Espaco.margem,
        right: Espaco.margem,
        top: Espaco.e8,
        bottom: MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.viewPaddingOf(context).bottom +
            Espaco.e16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Rotulo('Cronograma'),
              const SizedBox(height: Espaco.e4),
              Text('Nova fase',
                  style: Tipografia.titulo.copyWith(color: c.grafite)),
              const SizedBox(height: Espaco.e16),
              TextFormField(
                controller: _nomeCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome da fase',
                  hintText: 'Ex.: Estrutura do 2º andar',
                ),
                validator: (v) => Validators.obrigatorio(v, 'O nome'),
              ),
              if (sugestoes.isNotEmpty) ...[
                const SizedBox(height: Espaco.e12),
                // Com o nome de uma fase padrão, a maquete ganha a peça
                // dessa fase.
                const Rotulo('Fases padrão que faltam'),
                const SizedBox(height: Espaco.e8),
                Wrap(
                  spacing: Espaco.e8,
                  runSpacing: Espaco.e8,
                  children: [
                    for (final nome in sugestoes)
                      ActionChip(
                        label: Text(nome),
                        onPressed: () => setState(() => _nomeCtrl.text = nome),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: Espaco.e16),
              Row(
                children: [
                  Expanded(
                    child: _CampoData(
                      rotulo: 'Início',
                      data: _inicio,
                      aoTocar: () => _escolherData(true),
                    ),
                  ),
                  const SizedBox(width: Espaco.entreAlvos),
                  Expanded(
                    child: _CampoData(
                      rotulo: 'Fim',
                      data: _fim,
                      aoTocar: () => _escolherData(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Espaco.e24),
              BotaoPrincipal(
                rotulo: 'Salvar fase',
                grande: true,
                expandir: true,
                carregando: _salvando,
                aoTocar: _salvando ? null : () => unawaited(_salvar()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampoData extends StatelessWidget {
  const _CampoData({
    required this.rotulo,
    required this.data,
    required this.aoTocar,
  });

  final String rotulo;
  final DateTime data;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: aoTocar,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: rotulo,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          Formatters.data(data),
          style: Tipografia.corpo.copyWith(
            color: context.cores.grafite,
            fontFeatures: Tipografia.tabular,
          ),
        ),
      ),
    );
  }
}
