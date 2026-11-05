import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../design/maquete/maquete.dart';
import '../../models/models.dart';
import '../../router/transicoes.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/perguntas_obra_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/chat_obra.dart';
import '../../widgets/imagem_obra.dart';
import '../planta/ficha_comodo.dart';

/// Acompanhamento da obra para quem a contratou, na linguagem da
/// prancheta: o carimbo com a fase e o avanço, a maquete "hoje" e
/// "pronta", a casa por dentro (planta tocável, ficha de cada cômodo e
/// vista 360°), as etapas e o que a equipe registrou no canteiro.
///
/// Só isso. Os lançamentos nem são consultados: as regras do Firestore
/// recusam a leitura para o perfil cliente, então não existe caminho, nem
/// por engano de tela, que traga valor para cá.
class ClienteObraScreen extends StatelessWidget {
  final String obraId;

  const ClienteObraScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) =>
      TemaPrancheta(child: _ClienteObra(obraId: obraId));
}

class _ClienteObra extends StatefulWidget {
  const _ClienteObra({required this.obraId});

  final String obraId;

  @override
  State<_ClienteObra> createState() => _ClienteObraState();
}

class _ClienteObraState extends State<_ClienteObra> {
  // Abertas uma vez (o StreamBuilder reassina quando a Stream muda).
  late final FirestoreService _db = context.read<FirestoreService>();
  late final Stream<ObraModel?> _obra = _db.obra(widget.obraId);
  late final Stream<List<CronogramaFaseModel>> _cronograma =
      _db.cronograma(widget.obraId);
  late final Stream<List<DiarioEntradaModel>> _diario =
      _db.diario(widget.obraId);
  late final Stream<PlantaObra?> _planta = _db.planta(widget.obraId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ObraModel?>(
      stream: _obra,
      builder: (context, obraSnap) {
        // Acesso recusado ou obra removida: sem isso a tela ficaria
        // carregando para sempre, sem dizer o que houve.
        if (obraSnap.hasError ||
            (obraSnap.connectionState == ConnectionState.active &&
                obraSnap.data == null)) {
          return Scaffold(
            appBar: AppBar(),
            body: const Padding(
              padding: EdgeInsets.all(Espaco.margem),
              child: AvisoVazio(
                icone: Icons.lock_outline,
                titulo: 'Não consegui abrir esta obra',
                texto: 'Seu acesso pode ter sido removido, ou a obra saiu do '
                    'ar. Fale com o responsável pela obra.',
              ),
            ),
          );
        }
        final obra = obraSnap.data;
        if (obra == null) {
          return Scaffold(
            appBar: AppBar(),
            body: ListView(
              padding: const EdgeInsets.all(Espaco.margem),
              children: const [
                EsqueletoFolha(linhas: 2, rotuloSemantico: 'Abrindo a obra'),
              ],
            ),
          );
        }
        return StreamBuilder<List<CronogramaFaseModel>>(
          stream: _cronograma,
          builder: (context, cronoSnap) =>
              StreamBuilder<List<DiarioEntradaModel>>(
            stream: _diario,
            builder: (context, diarioSnap) => StreamBuilder<PlantaObra?>(
              stream: _planta,
              builder: (context, plantaSnap) => _Acompanhamento(
                obra: obra,
                cronograma: cronoSnap.data,
                diario: diarioSnap.data ?? const [],
                // Sem permissão (regras antigas) ou sem planta: a
                // casa-padrão e nada de "por dentro".
                planta: plantaSnap.hasError ? null : plantaSnap.data,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Acompanhamento extends StatefulWidget {
  const _Acompanhamento({
    required this.obra,
    required this.cronograma,
    required this.diario,
    required this.planta,
  });

  final ObraModel obra;

  /// Nulo enquanto carrega.
  final List<CronogramaFaseModel>? cronograma;
  final List<DiarioEntradaModel> diario;
  final PlantaObra? planta;

  @override
  State<_Acompanhamento> createState() => _AcompanhamentoState();
}

class _AcompanhamentoState extends State<_Acompanhamento> {
  /// A maquete mostra a obra hoje (false) ou pronta (true).
  bool _pronta = false;

  List<CronogramaFaseModel> get _fases =>
      [...?widget.cronograma]..sort((a, b) => a.ordem.compareTo(b.ordem));

  CronogramaFaseModel? get _faseAtual {
    final fases = _fases;
    return fases
            .where((f) => f.percentualConcluido > 0 && f.percentualConcluido < 100)
            .firstOrNull ??
        fases.where((f) => f.percentualConcluido < 100).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final obra = widget.obra;
    final planta = widget.planta;
    final fases = _fases;
    final progresso = ProgressoMaquete.doCronograma(widget.cronograma);
    final atual = _faseAtual;
    final selo = switch (obra.status) {
      StatusObra.emAndamento => null,
      StatusObra.pausada =>
        const SeloStatus(StatusSelo.aviso, texto: 'Obra pausada'),
      StatusObra.concluida =>
        const SeloStatus(StatusSelo.aprovado, texto: 'Obra concluída'),
    };
    final recentes = [...widget.diario]..sort((a, b) => b.data.compareTo(a.data));

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.only(top: Espaco.e4, bottom: Espaco.e32),
        children: [
          _NaMargem(Carimbo(linhas: [
            [
              CelulaCarimbo(
                rotulo: 'Sua obra',
                conteudo: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        obra.nome,
                        style: Tipografia.tituloTela.copyWith(color: c.grafite),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: Espaco.e4),
                    Text(obra.endereco,
                        style: Tipografia.apoio.copyWith(color: c.grafite2)),
                    if (selo != null) ...[
                      const SizedBox(height: Espaco.e8),
                      selo,
                    ],
                  ],
                ),
              ),
            ],
            [
              CelulaCarimbo(
                rotulo: 'Fase',
                valor: widget.cronograma == null
                    ? '…'
                    : atual?.nome ??
                        (fases.isEmpty ? obra.status.label : 'Concluídas'),
                flex: 2,
              ),
              CelulaCarimbo(
                rotulo: 'Avanço',
                valor: '${progresso.percentualObra}%',
              ),
            ],
            [
              CelulaCarimbo(
                rotulo: 'Entrega prevista',
                valor: Formatters.data(obra.previsaoTermino),
                flex: 2,
              ),
              CelulaCarimbo(
                rotulo: 'Prazo',
                valor: obra.duracaoDias <= 0
                    ? '—'
                    : '${obra.diasDecorridos.clamp(0, obra.duracaoDias)} '
                        'de ${obra.duracaoDias} dias',
              ),
            ],
          ])),
          const SizedBox(height: Espaco.e24),
          _NaMargem(SeletorGrande<bool>(
            rotulo: 'A casa',
            opcoes: const [
              OpcaoSeletor(valor: false, rotulo: 'Hoje', icone: Icons.construction),
              OpcaoSeletor(valor: true, rotulo: 'Pronta', icone: Icons.home_outlined),
            ],
            selecionado: _pronta,
            aoMudar: (v) => setState(() => _pronta = v),
          )),
          const SizedBox(height: Espaco.e12),
          if (widget.cronograma == null)
            const SizedBox(height: 220)
          else
            MaqueteObra(
              // "Pronta": todas as fases inteiras. A troca anima: a casa se
              // completa (ou volta para o que está hoje).
              progresso: _pronta
                  ? ProgressoMaquete.fases(
                      List<double>.filled(ProgressoMaquete.totalFases, 1))
                  : progresso,
              altura: 240,
              legenda: !_pronta,
              fonte: planta == null
                  ? FonteMaquete.padrao
                  : FontePlanta(planta),
            ),
          const SizedBox(height: Espaco.e8),
          _NaMargem(Text(
            _pronta
                ? 'Como a casa fica pronta.'
                : progresso.semCronograma
                    ? 'A equipe ainda não montou o cronograma.'
                    : '${progresso.percentualObra}% da obra'
                        '${atual == null ? '' : ' · ${atual.nome} em ${atual.percentualConcluido}%'}.',
            style: Tipografia.apoio.copyWith(color: c.grafite2),
          )),
          if (planta != null) ...[
            _Secao(
              titulo: 'A casa por dentro',
              child: _PorDentro(obraId: obra.id, planta: planta),
            ),
          ],
          if (fases.isNotEmpty)
            _Secao(
              titulo: 'Etapas da obra',
              child: Folha(
                preenchimento: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < fases.length; i++)
                      LinhaLista(
                        titulo: fases[i].nome,
                        apoio: _situacao(fases[i]),
                        valor: '${fases[i].percentualConcluido}%',
                        icone: fases[i].concluida ? Icons.check : null,
                        margemHorizontal: Espaco.e12,
                        divisoria: i < fases.length - 1,
                      ),
                  ],
                ),
              ),
            ),
          _Secao(
            titulo: 'O que aconteceu no canteiro',
            child: recentes.isEmpty
                ? const AvisoVazio(
                    icone: Icons.event_note_outlined,
                    titulo: 'Nenhum registro ainda',
                    texto: 'A equipe ainda não registrou nenhum dia de '
                        'trabalho.',
                  )
                : Folha(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, e) in recentes.take(5).indexed) ...[
                          if (i > 0) ...[
                            const SizedBox(height: Espaco.e12),
                            Divider(color: c.grade, thickness: Traco.fino, height: 1),
                            const SizedBox(height: Espaco.e12),
                          ],
                          _RegistroDoDia(entrada: e),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BarraDeAcao(
        principal: BotaoContorno(
          rotulo: 'Perguntar sobre a obra',
          icone: Icons.chat_bubble_outline,
          expandir: true,
          aoTocar: () => _abrirChat(context),
        ),
      ),
    );
  }

  static String _situacao(CronogramaFaseModel f) {
    final datas = '${Formatters.dataCurta(f.dataInicio)} a '
        '${Formatters.dataCurta(f.dataFim)}';
    if (f.concluida) return 'Concluída · $datas';
    if (f.atrasada) return 'Em atraso · $datas';
    if (f.percentualConcluido > 0 || f.emAndamento) {
      return 'Em andamento · $datas';
    }
    return 'A começar · $datas';
  }

  void _abrirChat(BuildContext context) {
    // Os dados do chat do cliente vão sem lançamento, estoque nem
    // movimento: não há o que somar, mesmo que a pergunta insista.
    final dados = DadosObraChat(
      obra: widget.obra,
      lancamentos: const [],
      diario: widget.diario,
      cronograma: widget.cronograma ?? const [],
      estoque: const [],
      movimentos: const [],
    );
    Navigator.of(context).push(rotaSuave(
      Scaffold(
        appBar: AppBar(title: Text('Assistente · ${widget.obra.nome}')),
        body: ChatObra(dados: dados, modoCliente: true),
      ),
    ));
  }
}

/// A planta numerada e tocável e a lista dos cômodos com teto. Tocar abre
/// a ficha do cômodo, com o botão da vista 360°.
class _PorDentro extends StatelessWidget {
  const _PorDentro({required this.obraId, required this.planta});

  final String obraId;
  final PlantaObra planta;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final comodos = [
      for (final x in planta.comodos)
        if (x.coberto) x,
    ];
    final numeros = {
      for (var i = 0; i < comodos.length; i++) comodos[i].id: i + 1,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Folha(
          preenchimento: EdgeInsets.zero,
          child: LayoutBuilder(
            builder: (context, caixa) => SizedBox(
              height: PlantaDesenhada.alturaPara(planta, caixa.maxWidth),
              child: PlantaDesenhada(
                planta: planta,
                numeros: numeros,
                aoTocarComodo: (x) => _abrir(context, x),
              ),
            ),
          ),
        ),
        const SizedBox(height: Espaco.e8),
        Text(
          'Toque num cômodo para ver as medidas e olhar em 360°.',
          style: Tipografia.apoio.copyWith(color: c.grafite2),
        ),
        const SizedBox(height: Espaco.e16),
        Folha(
          preenchimento: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < comodos.length; i++)
                LinhaLista(
                  inicio: NumeroDeLegenda(i + 1),
                  titulo: comodos[i].nome,
                  apoio: medidasDoComodo(comodos[i]),
                  valor: areaDoComodo(comodos[i]),
                  margemHorizontal: Espaco.e12,
                  divisoria: i < comodos.length - 1,
                  aoTocar: () => _abrir(context, comodos[i]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _abrir(BuildContext context, ComodoPlanta comodo) {
    unawaited(Tato.leve());
    unawaited(showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              Espaco.margem, Espaco.e8, Espaco.margem, Espaco.e16),
          child: FichaComodo(
            planta: planta,
            comodo: comodo,
            acao: BotaoPrincipal(
              rotulo: 'Ver em 360°',
              icone: Icons.threesixty,
              expandir: true,
              aoTocar: () {
                Navigator.pop(ctx);
                context.push('/cliente/$obraId/planta/${comodo.id}/360');
              },
            ),
          ),
        ),
      ),
    ));
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

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Espaco.margem, Espaco.e32, Espaco.margem, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            container: true,
            child: LinhaCota(legenda: titulo),
          ),
          const SizedBox(height: Espaco.e16),
          child,
        ],
      ),
    );
  }
}

class _RegistroDoDia extends StatelessWidget {
  const _RegistroDoDia({required this.entrada});

  final DiarioEntradaModel entrada;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParComValor(
          esquerda: Text(
            Formatters.diaSemana(entrada.data),
            style: Tipografia.corpoForte.copyWith(color: c.grafite),
          ),
          direita: Text(
            entrada.clima,
            style: Tipografia.apoio.copyWith(color: c.grafite2),
          ),
        ),
        const SizedBox(height: Espaco.e4),
        Text(entrada.descricao,
            style: Tipografia.corpo.copyWith(color: c.grafite)),
        if (entrada.fotosUrls.isNotEmpty) ...[
          const SizedBox(height: Espaco.e8),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entrada.fotosUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: Espaco.e8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: Raio.cantoPequeno,
                child: SizedBox(
                  width: 150,
                  child: ImagemObra(entrada.fotosUrls[i]),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
