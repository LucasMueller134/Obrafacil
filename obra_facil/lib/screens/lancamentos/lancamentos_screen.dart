import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import 'lancamentos_partes.dart';

/// Gastos da obra e fila de aprovação do dono (/obras/:id/lancamentos).
///
/// A tela fica na prancheta ([TemaPrancheta], claro ou escuro pelo
/// sistema). Para o dono com gastos pendentes ela abre já no filtro
/// "Pendentes" (ou com `?filtro=pendentes` na rota, vindo da central): um
/// cartão por gasto, com Aprovar e Recusar à vista; deslizar continua como
/// atalho.
///
/// Aprovar não pede confirmação: o cartão sai da fila na hora e o aviso
/// "Aprovado" oferece Desfazer por 4 s. Só quando o aviso fecha sem
/// desfazer a aprovação é gravada (a mesma [_FilaDeLancamentosState._aprovar]
/// de antes, com os mesmos argumentos). Se a pessoa sair da tela ou do app
/// antes, a aprovação é gravada na hora: não se perde.
class LancamentosScreen extends StatelessWidget {
  final String obraId;

  const LancamentosScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) =>
      TemaPrancheta(child: _FilaDeLancamentos(obraId: obraId));
}

/// Os filtros do topo.
enum _Filtro { pendentes, aprovados, recusados, todos }

/// Uma ação gravada só quando o aviso de desfazer fecha.
class _Adiado {
  _Adiado({required this.ids, required this.efetivar});

  /// Lançamentos que saíram da tela por causa desta ação.
  final Set<String> ids;

  /// A gravação de verdade (as mesmas chamadas de antes).
  final Future<void> Function() efetivar;

  /// Já gravou ou foi desfeita: não faz de novo.
  bool resolvido = false;
}

class _FilaDeLancamentos extends StatefulWidget {
  const _FilaDeLancamentos({required this.obraId});

  final String obraId;

  @override
  State<_FilaDeLancamentos> createState() => _FilaDeLancamentosState();
}

class _FilaDeLancamentosState extends State<_FilaDeLancamentos> {
  /// Nulo até chegar a primeira lista (o filtro inicial depende dela).
  _Filtro? _filtro;

  /// `?filtro=` da rota, lido uma vez.
  String? _filtroDaRota;
  bool _leuRota = false;

  late Stream<List<LancamentoModel>> _lancamentos;

  /// Saíram da fila nesta tela (aprovados ou excluídos, com o desfazer
  /// correndo ou já gravados) e o stream ainda os mostra como pendentes:
  /// ficam escondidos. Quando o stream muda o status, voltam a aparecer
  /// na lista certa.
  final Set<String> _ocultos = {};

  /// Saíram pelo deslize: o Dismissible já recolheu o cartão, então ele
  /// some sem a animação de saída.
  final Set<String> _deslizados = {};

  final List<_Adiado> _adiados = [];

  /// A última aprovação desta tela que mexe em cada material do estoque.
  /// Ver [_aprovarNaVez].
  final Map<String, Future<void>> _ultimaNoEstoque = {};

  late final AppLifecycleListener _ciclo;
  ScaffoldMessengerState? _mensageiro;

  @override
  void initState() {
    super.initState();
    _lancamentos = context.read<FirestoreService>().lancamentos(widget.obraId);
    // App para o fundo com aprovação no desfazer: grava já (o sistema pode
    // fechar o app antes dos 4 s).
    _ciclo = AppLifecycleListener(onHide: _aoEsconderApp);
  }

  @override
  void didUpdateWidget(_FilaDeLancamentos antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.obraId != widget.obraId) {
      _lancamentos =
          context.read<FirestoreService>().lancamentos(widget.obraId);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mensageiro = ScaffoldMessenger.maybeOf(context);
    if (!_leuRota) {
      _leuRota = true;
      _filtroDaRota = _lerFiltroDaRota(context);
    }
  }

  @override
  void dispose() {
    // Saiu da tela com o desfazer correndo: grava agora e tira o aviso
    // (o Desfazer não teria mais o que desfazer).
    if (_efetivarAdiados()) {
      final mensageiro = _mensageiro;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mensageiro != null && mensageiro.mounted) {
          mensageiro.hideCurrentSnackBar();
        }
      });
    }
    _ciclo.dispose();
    super.dispose();
  }

  void _aoEsconderApp() {
    if (_efetivarAdiados() && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  static String? _lerFiltroDaRota(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.queryParameters['filtro'];
    } on GoError {
      // Fora do router (teste da tela sozinha): sem filtro na rota.
      return null;
    }
  }

  _Filtro _filtroInicial(List<LancamentoModel> itens, AuthProvider auth) {
    switch (_filtroDaRota) {
      case 'pendentes':
        return _Filtro.pendentes;
      case 'aprovados':
        return _Filtro.aprovados;
      case 'recusados':
        return _Filtro.recusados;
      case 'todos':
        return _Filtro.todos;
    }
    final temPendente =
        itens.any((l) => l.status == StatusLancamento.pendente);
    return auth.ehDono && temPendente ? _Filtro.pendentes : _Filtro.todos;
  }

  /// Pendente no stream, mas já aprovado ou excluído aqui.
  bool _oculto(LancamentoModel l) =>
      l.status == StatusLancamento.pendente && _ocultos.contains(l.id);

  // ------------------------------------------------------------ Desfazer

  /// Aprova com desfazer: vibra, tira da fila na hora e mostra o aviso. A
  /// gravação ([_aprovar], igual à de antes, uma chamada por gasto) só
  /// acontece quando o aviso fecha sem desfazer, ou quando a pessoa sai da
  /// tela.
  void _pedirAprovacao(
    List<LancamentoModel> itens, {
    bool deslizou = false,
  }) {
    final novos = itens.where((l) => !_ocultos.contains(l.id)).toList();
    if (novos.isEmpty) return;
    final db = context.read<FirestoreService>();
    final donoId = context.read<AuthProvider>().usuario!.id;
    final contexto = context;
    unawaited(Tato.confirmar());
    final adiado = _Adiado(
      ids: {for (final l in novos) l.id},
      // Como N aprovações separadas (era assim com N deslizes): uma não
      // espera a outra terminar, salvo quando as duas mexem no mesmo
      // material ([_aprovarNaVez]).
      efetivar: () => Future.wait([
        for (final l in novos) _aprovarNaVez(contexto, l, db, donoId),
      ]),
    );
    setState(() {
      _ocultos.addAll(adiado.ids);
      if (deslizou) _deslizados.addAll(adiado.ids);
    });
    _mostrarAdiado(
      adiado,
      novos.length == 1 ? 'Aprovado' : '${novos.length} aprovados',
    );
  }

  /// O mestre exclui o próprio pendente, com desfazer. A chamada é a de
  /// antes, só que depois do aviso.
  void _pedirExclusao(LancamentoModel l) {
    final db = context.read<FirestoreService>();
    unawaited(Tato.confirmar());
    final adiado = _Adiado(
      ids: {l.id},
      efetivar: () async {
        try {
          await db.excluirLancamento(l.obraId, l.id);
        } catch (erro, pilha) {
          _falhou(l, 'excluir', erro, pilha);
        }
      },
    );
    setState(() => _ocultos.add(l.id));
    _mostrarAdiado(adiado, 'Lançamento excluído');
  }

  void _mostrarAdiado(_Adiado adiado, String mensagem) {
    _adiados.add(adiado);
    final aviso = mostrarAviso(
      context,
      mensagem,
      aoDesfazer: () => _desfazer(adiado),
    );
    // Fechou por tempo, deslizado, ou porque outro aviso entrou no lugar:
    // grava. (Desfazer marca como resolvido antes de fechar.)
    unawaited(aviso.closed.then((_) => _efetivar(adiado)));
  }

  void _desfazer(_Adiado adiado) {
    if (adiado.resolvido) return;
    adiado.resolvido = true;
    _adiados.remove(adiado);
    if (!mounted) return;
    setState(() {
      _ocultos.removeAll(adiado.ids);
      _deslizados.removeAll(adiado.ids);
    });
  }

  Future<void> _efetivar(_Adiado adiado) {
    if (adiado.resolvido) return Future<void>.value();
    adiado.resolvido = true;
    _adiados.remove(adiado);
    return adiado.efetivar();
  }

  /// Grava tudo o que ainda está no desfazer. Diz se havia algo.
  bool _efetivarAdiados() {
    final pendentes = List.of(_adiados);
    for (final adiado in pendentes) {
      unawaited(_efetivar(adiado));
    }
    return pendentes.isNotEmpty;
  }

  /// Chama a [_aprovar] de sempre para um gasto, sem deixar o erro solto.
  ///
  /// Sem sinal, a escrita do Firestore fica gravada no aparelho na hora,
  /// mas o `await` dela só termina quando chega ao servidor. Se uma
  /// aprovação esperasse a anterior terminar, sem sinal só a primeira
  /// ficaria gravada no aparelho e as outras dependeriam de o app ficar
  /// aberto até a internet voltar. Por isso cada uma começa na hora.
  ///
  /// A exceção são dois gastos com o mesmo material: a entrada no estoque
  /// lê a quantidade e grava a soma, e duas ao mesmo tempo leriam o mesmo
  /// número (uma entrada se perderia). Aí a segunda espera a primeira.
  Future<void> _aprovarNaVez(
    BuildContext contexto,
    LancamentoModel l,
    FirestoreService db,
    String donoId,
  ) {
    Future<void> aprovar() async {
      try {
        await _aprovar(contexto, l, db, donoId);
      } catch (erro, pilha) {
        _falhou(l, 'concluir a aprovação de', erro, pilha);
      }
    }

    final materiais = {for (final item in l.itens) item.material};
    final anteriores = [
      for (final m in materiais)
        if (_ultimaNoEstoque[m] case final anterior?) anterior,
    ];
    final esta = anteriores.isEmpty
        ? aprovar()
        : Future.wait(anteriores).then((_) => aprovar());
    for (final m in materiais) {
      _ultimaNoEstoque[m] = esta;
    }
    unawaited(esta.whenComplete(() {
      _ultimaNoEstoque.removeWhere((_, f) => identical(f, esta));
    }));
    return esta;
  }

  /// A gravação falhou: o cartão volta e a pessoa fica sabendo.
  void _falhou(
    LancamentoModel l,
    String acao,
    Object erro,
    StackTrace pilha,
  ) {
    debugPrint('Falha ao $acao ${l.id}: $erro\n$pilha');
    if (!mounted) return;
    unawaited(Tato.erro());
    setState(() {
      _ocultos.remove(l.id);
      _deslizados.remove(l.id);
    });
    mostrarAviso(
      context,
      'Não deu para $acao “${l.descricao}”. Confira a internet e veja '
      'a lista de novo.',
    );
  }

  // ---------------------------------------------------------------- Tela

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos')),
      body: StreamBuilder<List<LancamentoModel>>(
        stream: _lancamentos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return ListView(
              padding: const EdgeInsets.all(Espaco.margem),
              children: const [
                EsqueletoFolha(rotuloSemantico: 'Carregando os gastos'),
                SizedBox(height: Espaco.e12),
                EsqueletoFolha(linhas: 2, comValor: false),
              ],
            );
          }
          final itens = snapshot.data ?? const <LancamentoModel>[];
          final filtro = _filtro ??= _filtroInicial(itens, auth);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Espaco.margem,
              Espaco.e8,
              Espaco.margem,
              Espaco.e32,
            ),
            children: _conteudo(context, itens, filtro, auth, db),
          );
        },
      ),
      bottomNavigationBar: BarraDeAcao(
        principal: BotaoMarca(
          rotulo: 'Lançar gasto',
          icone: Icons.add,
          grande: true,
          expandir: true,
          aoTocar: () =>
              context.push('/obras/${widget.obraId}/lancamentos/novo'),
        ),
      ),
    );
  }

  List<Widget> _conteudo(
    BuildContext context,
    List<LancamentoModel> todos,
    _Filtro filtro,
    AuthProvider auth,
    FirestoreService db,
  ) {
    final visiveis = todos.where((l) => !_oculto(l)).toList();
    final pendentes =
        visiveis.where((l) => l.status == StatusLancamento.pendente).toList();
    final nPendentes = pendentes.length;

    final seletor = SeletorGrande<_Filtro>(
      opcoes: [
        // O número antes: escolhida, a opção ganha o check e, em 360 dp
        // com fonte grande, "Pendentes 3" não cabia e saía "Pendentes…"
        // (o número sumia). "3 pendentes" quebra em "3" / "pendentes".
        OpcaoSeletor(
          valor: _Filtro.pendentes,
          rotulo: switch (nPendentes) {
            0 => 'Pendentes',
            1 => '1 pendente',
            _ => '$nPendentes pendentes',
          },
        ),
        const OpcaoSeletor(valor: _Filtro.aprovados, rotulo: 'Aprovados'),
        const OpcaoSeletor(valor: _Filtro.recusados, rotulo: 'Recusados'),
        const OpcaoSeletor(valor: _Filtro.todos, rotulo: 'Todos'),
      ],
      selecionado: filtro,
      aoMudar: (f) => setState(() => _filtro = f),
    );
    final filhos = <Widget>[seletor, const SizedBox(height: Espaco.e24)];

    if (todos.isEmpty) {
      filhos.add(const AvisoVazio(
        icone: Icons.receipt_long_outlined,
        titulo: 'Nenhum gasto lançado',
        texto: 'Registre o primeiro gasto da obra pela foto da nota, por '
            'voz ou digitando: é o botão Lançar gasto, aqui embaixo.',
      ));
      return filhos;
    }

    // O dono decide os pendentes em cartões (Pendentes e Todos).
    final fila = auth.ehDono &&
        (filtro == _Filtro.pendentes ||
            (filtro == _Filtro.todos && nPendentes > 0));
    if (fila) {
      if (nPendentes == 0) {
        filhos.add(AvisoVazio(
          icone: Icons.task_alt,
          titulo: 'Nada para aprovar',
          texto: 'Os gastos que a equipe lançar aparecem aqui para você '
              'aprovar ou recusar.',
          acao: BotaoContorno(
            rotulo: 'Ver todos os gastos',
            expandir: true,
            aoTocar: () => setState(() => _filtro = _Filtro.todos),
          ),
        ));
        return filhos;
      }
      filhos
        ..add(CabecalhoPendentes(
          quantidade: nPendentes,
          total: _soma(pendentes),
          aoAprovarTodos:
              nPendentes >= 2 ? () => _pedirAprovacao(pendentes) : null,
        ))
        ..add(const SizedBox(height: Espaco.e16));
      for (final l in todos) {
        if (l.status != StatusLancamento.pendente) continue;
        filhos.add(_itemDaFila(context, l, auth, db));
      }
      if (filtro == _Filtro.pendentes) return filhos;

      final historico =
          visiveis.where((l) => l.status != StatusLancamento.pendente);
      if (historico.isNotEmpty) {
        filhos
          ..add(const SizedBox(height: Espaco.e12))
          ..add(const LinhaCota(legenda: 'Já decididos'))
          ..add(const SizedBox(height: Espaco.e12))
          ..addAll(_linhas(context, historico.toList(), auth));
      }
      return filhos;
    }

    final (lista, cabecalho, vazio) = switch (filtro) {
      _Filtro.pendentes => (
          pendentes,
          CabecalhoLista(
            rotulo: nPendentes == 1
                ? '1 aguardando aprovação'
                : '$nPendentes aguardando aprovação',
            total: _soma(pendentes),
          ),
          const AvisoVazio(
            icone: Icons.task_alt,
            titulo: 'Nenhum gasto pendente',
            texto: 'Tudo o que foi lançado já foi aprovado ou recusado pelo '
                'dono da obra.',
          ),
        ),
      _Filtro.aprovados => _secao(
          visiveis,
          StatusLancamento.aprovado,
          (n) => n == 1 ? '1 aprovado' : '$n aprovados',
          'Nenhum gasto aprovado ainda',
        ),
      _Filtro.recusados => _secao(
          visiveis,
          StatusLancamento.rejeitado,
          (n) => n == 1 ? '1 recusado' : '$n recusados',
          'Nenhum gasto recusado',
        ),
      _Filtro.todos => (
          visiveis,
          CabecalhoLista(
            rotulo: 'Aprovado até agora',
            total: _soma(visiveis
                .where((l) => l.status == StatusLancamento.aprovado)),
            apoio: _contagem(visiveis),
          ),
          const AvisoVazio(
            icone: Icons.receipt_long_outlined,
            titulo: 'Nenhum gasto',
            texto: 'Os gastos lançados na obra aparecem aqui.',
          ),
        ),
    };
    if (lista.isEmpty) {
      filhos.add(vazio);
      return filhos;
    }
    filhos
      ..add(cabecalho)
      ..add(const SizedBox(height: Espaco.e16))
      ..addAll(_linhas(context, lista, auth));
    return filhos;
  }

  (List<LancamentoModel>, Widget, Widget) _secao(
    List<LancamentoModel> visiveis,
    StatusLancamento status,
    String Function(int) rotulo,
    String vazio,
  ) {
    final lista = visiveis.where((l) => l.status == status).toList();
    return (
      lista,
      CabecalhoLista(rotulo: rotulo(lista.length), total: _soma(lista)),
      AvisoVazio(
        icone: Icons.receipt_long_outlined,
        titulo: vazio,
        texto: 'Troque o filtro acima para ver os outros gastos.',
      ),
    );
  }

  static double _soma(Iterable<LancamentoModel> itens) =>
      itens.fold<double>(0, (s, l) => s + l.valor);

  /// "20 lançamentos · 3 pendentes · 1 recusado".
  static String _contagem(List<LancamentoModel> itens) {
    int de(StatusLancamento s) => itens.where((l) => l.status == s).length;
    final pend = de(StatusLancamento.pendente);
    final rec = de(StatusLancamento.rejeitado);
    return [
      itens.length == 1 ? '1 lançamento' : '${itens.length} lançamentos',
      if (pend > 0) pend == 1 ? '1 pendente' : '$pend pendentes',
      if (rec > 0) rec == 1 ? '1 recusado' : '$rec recusados',
    ].join(' · ');
  }

  /// Um cartão da fila do dono: some ao aprovar (com animação, a menos
  /// que tenha saído pelo deslize) e volta no Desfazer.
  Widget _itemDaFila(
    BuildContext context,
    LancamentoModel l,
    AuthProvider auth,
    FirestoreService db,
  ) {
    final chave = ValueKey('fila-${l.id}');
    final oculto = _ocultos.contains(l.id);
    if (oculto && _deslizados.contains(l.id)) {
      return SizedBox(key: chave, width: double.infinity);
    }
    final cartao = CartaoPendente(
      lancamento: l,
      aoAbrir: () => _abrirDetalhes(context, l, auth),
      aoAprovar: () => _pedirAprovacao([l]),
      aoRecusar: () =>
          unawaited(_rejeitar(context, l, db, auth.usuario!.id)),
    );
    // Atalho: deslizar para a direita aprova, para a esquerda recusa.
    final reduzir = context.reduzirAnimacoes;
    final deslizavel = Dismissible(
      key: ValueKey(l.id),
      // Com "reduzir animações", o cartão solto não corre sozinho até a
      // borda (nem volta correndo) e não encolhe: sai na hora.
      movementDuration:
          reduzir ? Duration.zero : const Duration(milliseconds: 200),
      resizeDuration: reduzir ? null : const Duration(milliseconds: 300),
      background: const FundoDeslize.aprovar(),
      secondaryBackground: const FundoDeslize.recusar(),
      confirmDismiss: (direcao) async {
        if (direcao == DismissDirection.startToEnd) return true;
        await _rejeitar(context, l, db, auth.usuario!.id);
        // o stream atualiza o status do card;
        // não removemos o item da lista
        return false;
      },
      onDismissed: (_) => _pedirAprovacao([l], deslizou: true),
      child: cartao,
    );
    return _Recolher(
      key: chave,
      recolhido: oculto,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Espaco.e16),
        child: deslizavel,
      ),
    );
  }

  /// As linhas da lista (aprovados, recusados, histórico e os pendentes
  /// para quem não decide), agrupadas numa folha. Sem o ícone da
  /// categoria: em 360 dp ele tirava do título a largura de uma palavra
  /// (a categoria está no detalhe).
  List<Widget> _linhas(
    BuildContext context,
    List<LancamentoModel> lista,
    AuthProvider auth,
  ) {
    return [
      for (var i = 0; i < lista.length; i++)
        TrechoDeLista(
          key: ValueKey('linha-${lista[i].id}'),
          primeiro: i == 0,
          ultimo: i == lista.length - 1,
          child: LinhaLista(
            titulo: lista[i].descricao,
            apoio: fornecedorEData(lista[i], emLinhas: true),
            valor: Formatters.moeda(lista[i].valor),
            fim: SeloStatus(seloDoStatus(lista[i].status)),
            divisoria: i < lista.length - 1,
            margemHorizontal: Espaco.e12,
            aoTocar: () => _abrirDetalhes(context, lista[i], auth),
          ),
        ),
    ];
  }

  void _abrirDetalhes(
      BuildContext context, LancamentoModel l, AuthProvider auth) {
    final db = context.read<FirestoreService>();
    final podeModerar = auth.ehDono && l.status == StatusLancamento.pendente;
    final podeExcluir = !auth.ehDono &&
        l.status == StatusLancamento.pendente &&
        l.criadoPorId == auth.usuario!.id;
    unawaited(showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FolhaDetalhe(
        lancamento: l,
        acoes: podeModerar
            ? ParDeDecisao(
                grande: true,
                aoAprovar: () {
                  Navigator.pop(ctx);
                  _pedirAprovacao([l]);
                },
                aoRecusar: () async {
                  Navigator.pop(ctx);
                  await _rejeitar(context, l, db, auth.usuario!.id);
                },
              )
            : podeExcluir
                ? BotaoContorno(
                    rotulo: 'Excluir lançamento',
                    icone: Icons.delete_outline,
                    expandir: true,
                    aoTocar: () {
                      Navigator.pop(ctx);
                      _pedirExclusao(l);
                    },
                  )
                : null,
      ),
    ));
  }

  /// Aprova e aplica os materiais no estoque (interligação financeiro→estoque).
  Future<void> _aprovar(BuildContext context, LancamentoModel l,
      FirestoreService db, String donoId) async {
    await db.moderarLancamento(
      lancamento: l,
      aprovar: true,
      donoId: donoId,
    );
    if (l.itens.isNotEmpty) {
      final resumo = await db.aplicarLancamentoNoEstoque(l);
      if (context.mounted && resumo.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Estoque atualizado: ${resumo.join(' · ')}'),
        ));
      }
    }
  }

  Future<void> _rejeitar(BuildContext context, LancamentoModel l,
      FirestoreService db, String donoId) async {
    final ctrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recusar gasto'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            hintText: 'Ex.: valor não confere com a nota',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            // Pressionado, outra cor sólida (o tema não tem véu): o
            // vermelho puxado para o grafite, que sobe o contraste do
            // texto nos dois temas.
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (estado) => estado.contains(WidgetState.pressed)
                    ? Color.lerp(ctx.cores.revisao, ctx.cores.grafite, 0.25)!
                    : ctx.cores.revisao,
              ),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Recusar'),
          ),
        ],
      ),
    );
    if (motivo == null) return;
    await db.moderarLancamento(
      lancamento: l,
      aprovar: false,
      donoId: donoId,
      motivoRejeicao: motivo.trim().isEmpty ? null : motivo.trim(),
    );
  }
}

/// Recolhe o cartão que saiu da fila (altura e opacidade) e o devolve no
/// Desfazer. Com "reduzir animações", troca na hora.
class _Recolher extends StatelessWidget {
  const _Recolher({super.key, required this.recolhido, required this.child});

  final bool recolhido;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: context.duracao(Movimento.medio),
      switchInCurve: Movimento.entrar,
      switchOutCurve: Movimento.sair,
      // O cartão que está saindo não aceita mais toque (nem um segundo
      // Aprovar). As chaves são as do AnimatedSwitcher: o mesmo filho
      // continua o mesmo elemento ao passar de atual para anterior.
      layoutBuilder: (atual, anteriores) => Stack(
        alignment: Alignment.topCenter,
        children: [
          for (final anterior in anteriores)
            IgnorePointer(key: anterior.key, child: anterior),
          if (atual != null)
            IgnorePointer(key: atual.key, ignoring: false, child: atual),
        ],
      ),
      transitionBuilder: (filho, animacao) => FadeTransition(
        opacity: animacao,
        child: SizeTransition(
          sizeFactor: animacao,
          alignment: Alignment.topCenter,
          child: filho,
        ),
      ),
      child: recolhido
          ? const SizedBox(key: ValueKey('recolhido'), width: double.infinity)
          : KeyedSubtree(key: const ValueKey('cartao'), child: child),
    );
  }
}
