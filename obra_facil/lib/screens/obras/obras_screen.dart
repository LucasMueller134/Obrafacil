import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../design/maquete/maquete.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/notificacoes/tarefa_segundo_plano.dart';
import '../../utils/formatters.dart';

/// A lista de obras, primeira tela depois do login, na linguagem da
/// prancheta: o nome de quem entrou no topo, uma folha por obra (nome,
/// endereço, término previsto e orçamento) e a ação principal no rodapé.
/// O dono cadastra obra nova; o mestre entra numa obra com o código de
/// convite.
class ObrasScreen extends StatelessWidget {
  const ObrasScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const TemaPrancheta(child: _ListaDeObras());
}

class _ListaDeObras extends StatefulWidget {
  const _ListaDeObras();

  @override
  State<_ListaDeObras> createState() => _ListaDeObrasState();
}

class _ListaDeObrasState extends State<_ListaDeObras> {
  /// A leitura das obras, aberta uma vez por usuário: o StreamBuilder
  /// reassina quando recebe uma Stream nova, e pedi-la a cada build
  /// reabriria o listener do Firestore a cada mudança no login.
  Stream<List<ObraModel>>? _obras;
  String? _dono;

  @override
  void initState() {
    super.initState();
    // permissão + lembretes agendados + verificador em segundo plano
    NotificacaoBootstrap.aplicar();
  }

  Stream<List<ObraModel>> _obrasDe(String usuarioId) {
    if (_obras == null || _dono != usuarioId) {
      _dono = usuarioId;
      _obras = context.read<FirestoreService>().obrasDoUsuario(usuarioId);
    }
    return _obras!;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final usuario = auth.usuario;
    if (usuario == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Notificações',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notificacoes'),
          ),
          if (usuario.ehDono)
            IconButton(
              tooltip: 'Fornecedores',
              icon: const Icon(Icons.storefront_outlined),
              onPressed: () => context.push('/fornecedores'),
            ),
          // "Sair" no menu, longe do polegar: tocar nele sem querer
          // derrubava a sessão no canteiro, sem sinal para entrar de novo.
          PopupMenuButton<String>(
            tooltip: 'Conta',
            icon: const Icon(Icons.more_vert),
            onSelected: (_) => _confirmarSaida(context),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'sair',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: Espaco.e12),
                    Text('Sair da conta'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: Espaco.e4),
        ],
      ),
      body: StreamBuilder<List<ObraModel>>(
        stream: _obrasDe(usuario.id),
        builder: (context, snapshot) => AnimatedSwitcher(
          duration: context.duracao(Movimento.medio),
          switchInCurve: Movimento.entrar,
          switchOutCurve: Movimento.sair,
          child: KeyedSubtree(
            key: ValueKey(_estado(snapshot)),
            child: _conteudo(context, snapshot, usuario, auth),
          ),
        ),
      ),
      bottomNavigationBar: BarraDeAcao(
        principal: usuario.ehDono
            ? BotaoPrincipal(
                rotulo: 'Nova obra',
                icone: Icons.add,
                grande: true,
                expandir: true,
                aoTocar: () => context.push('/obras/nova'),
              )
            : BotaoPrincipal(
                rotulo: 'Entrar com código',
                icone: Icons.vpn_key_outlined,
                grande: true,
                expandir: true,
                aoTocar: () => _entrarComCodigo(context),
              ),
      ),
    );
  }

  /// Carregando, erro ou lista: troca com fade só quando muda de estado,
  /// não a cada obra que chega.
  static String _estado(AsyncSnapshot<List<ObraModel>> s) {
    if (s.connectionState == ConnectionState.waiting) return 'carregando';
    if (s.hasError) return 'erro';
    return 'lista';
  }

  Widget _conteudo(
    BuildContext context,
    AsyncSnapshot<List<ObraModel>> snapshot,
    UsuarioModel usuario,
    AuthProvider auth,
  ) {
    final obras = snapshot.data ?? const <ObraModel>[];
    final carregando = snapshot.connectionState == ConnectionState.waiting;

    final List<Widget> corpo;
    if (carregando) {
      corpo = const [
        EsqueletoFolha(rotuloSemantico: 'Buscando suas obras'),
        SizedBox(height: Espaco.e12),
        ExcludeSemantics(child: EsqueletoFolha()),
      ];
    } else if (snapshot.hasError) {
      corpo = const [
        AvisoVazio(
          icone: Icons.cloud_off_outlined,
          titulo: 'As obras não carregaram',
          texto: 'Confira a internet e abra o app de novo. O que já foi '
              'salvo no aparelho continua guardado.',
        ),
      ];
    } else if (obras.isEmpty) {
      corpo = [
        usuario.ehDono
            ? const AvisoVazio(
                icone: Icons.domain_add_outlined,
                titulo: 'Nenhuma obra ainda',
                texto: 'Toque em "Nova obra", aqui embaixo, para cadastrar a '
                    'primeira e começar a controlar custos, equipe e avanço.',
              )
            : const AvisoVazio(
                icone: Icons.vpn_key_outlined,
                titulo: 'Você ainda não está em nenhuma obra',
                texto: 'Peça ao dono da obra o código de convite e toque em '
                    '"Entrar com código", aqui embaixo.',
              ),
      ];
    } else {
      corpo = [
        for (var i = 0; i < obras.length; i++) ...[
          if (i > 0) const SizedBox(height: Espaco.e12),
          _FolhaObra(obra: obras[i]),
        ],
      ];
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Espaco.margem,
        Espaco.e4,
        Espaco.margem,
        Espaco.e32,
      ),
      children: [
        _Cabecalho(usuario: usuario, obras: carregando ? null : obras),
        const SizedBox(height: Espaco.e24),
        // Dono e mestre não ficam presos por causa do e-mail — só são
        // lembrados. Quem é barrado sem confirmar é o cliente, que é
        // gente de fora e entra por cadastro aberto.
        if (!auth.emailVerificado) ...[
          const _AvisoEmailPendente(),
          const SizedBox(height: Espaco.e16),
        ],
        if (!carregando && obras.isNotEmpty) ...[
          Semantics(
            header: true,
            container: true,
            child: LinhaCota(
              legenda: obras.length == 1 ? '1 obra' : '${obras.length} obras',
            ),
          ),
          const SizedBox(height: Espaco.e16),
        ],
        ...corpo,
      ],
    );
  }

  Future<void> _confirmarSaida(BuildContext context) async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text('Para entrar de novo, é preciso internet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (sair == true && context.mounted) {
      await context.read<AuthProvider>().sair();
    }
  }

  Future<void> _entrarComCodigo(BuildContext context) async {
    final ctrl = TextEditingController();
    final codigo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrar numa obra'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          style: Tipografia.codigo.copyWith(
            fontSize: 22,
            letterSpacing: 4,
            color: ctx.cores.grafite,
          ),
          decoration: const InputDecoration(
            labelText: 'Código de convite',
            hintText: 'A3B7XZ',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
    // Sem dispose aqui: o campo ainda está na tela durante a animação de
    // saída do diálogo.
    if (codigo == null || codigo.trim().isEmpty || !context.mounted) return;

    final db = context.read<FirestoreService>();
    final uid = context.read<AuthProvider>().usuario!.id;
    final obra = await db.entrarNaObraPorCodigo(codigo, uid);
    if (!context.mounted) return;
    if (obra == null) {
      unawaited(Tato.erro());
    } else {
      unawaited(Tato.confirmar());
    }
    mostrarAviso(
      context,
      obra == null
          ? 'Código não encontrado. Confira com o dono da obra.'
          : 'Você entrou na obra "${obra.nome}".',
    );
  }
}

/// Quem entrou e o que tem na lista. É o título da tela (o AppBar fica só
/// com os ícones, como na central da obra).
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.usuario, required this.obras});

  final UsuarioModel usuario;

  /// Nulo enquanto carrega.
  final List<ObraModel>? obras;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final emAndamento =
        obras?.where((o) => o.status == StatusObra.emAndamento).length;
    final primeiroNome = usuario.nome.trim().split(RegExp(r'\s+')).first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Rotulo(usuario.perfil.label),
        const SizedBox(height: Espaco.e4),
        Semantics(
          header: true,
          child: Text(
            primeiroNome.isEmpty ? 'Suas obras' : 'Olá, $primeiroNome',
            style: Tipografia.tituloTela.copyWith(color: c.grafite),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (emAndamento != null && obras!.isNotEmpty) ...[
          const SizedBox(height: Espaco.e4),
          Text(
            emAndamento == 1
                ? '1 obra em andamento'
                : '$emAndamento obras em andamento',
            style: Tipografia.apoio.copyWith(color: c.grafite2),
          ),
        ],
      ],
    );
  }
}

/// Uma obra da lista: a folha inteira é o botão que abre a central. Mostra
/// a fase em que a obra está e o avanço físico, com a mesma conta da
/// central (a média das fases do cronograma).
class _FolhaObra extends StatefulWidget {
  const _FolhaObra({required this.obra});

  final ObraModel obra;

  @override
  State<_FolhaObra> createState() => _FolhaObraState();
}

class _FolhaObraState extends State<_FolhaObra> {
  late Stream<List<CronogramaFaseModel>> _cronograma;

  @override
  void initState() {
    super.initState();
    _cronograma = context.read<FirestoreService>().cronograma(widget.obra.id);
  }

  @override
  void didUpdateWidget(_FolhaObra antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.obra.id != widget.obra.id) {
      _cronograma =
          context.read<FirestoreService>().cronograma(widget.obra.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CronogramaFaseModel>>(
      stream: _cronograma,
      builder: (context, snap) =>
          _folha(context, snap.hasError ? const [] : snap.data),
    );
  }

  Widget _folha(BuildContext context, List<CronogramaFaseModel>? cronograma) {
    final obra = widget.obra;
    final c = context.cores;
    final avanco = _Avanco.de(cronograma);
    final selo = switch (obra.status) {
      StatusObra.emAndamento => null,
      StatusObra.pausada =>
        const SeloStatus(StatusSelo.aviso, texto: 'Obra pausada'),
      StatusObra.concluida =>
        const SeloStatus(StatusSelo.aprovado, texto: 'Obra concluída'),
    };
    final termino = Formatters.data(obra.previsaoTermino);
    final orcamento = Formatters.moedaCompacta(obra.orcamento);

    return AreaPressionavel(
      aoTocar: () => context.push('/obras/${obra.id}'),
      vibrar: true,
      rotuloSemantico: [
        obra.nome,
        if (selo != null) obra.status.label,
        obra.endereco,
        if (avanco != null) avanco.semantica,
        'término previsto $termino',
        'orçamento $orcamento',
      ].join(', '),
      construtor: (context, e) => Folha(
        cor: e.pressionado ? c.folhaRebaixada : null,
        preenchimento: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaco.e16,
                Espaco.e16,
                Espaco.e8,
                Espaco.e16,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          obra.nome,
                          style: Tipografia.titulo.copyWith(color: c.grafite),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: Espaco.e4),
                        Text(
                          obra.endereco,
                          style: Tipografia.apoio.copyWith(color: c.grafite2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (selo != null) ...[
                          const SizedBox(height: Espaco.e12),
                          selo,
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Espaco.e4),
                  Padding(
                    padding: const EdgeInsets.only(top: Espaco.e4),
                    child: Icon(Icons.chevron_right, color: c.traco),
                  ),
                ],
              ),
            ),
            _CrescerSuave(
              child: avanco == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Espaco.e16,
                        0,
                        Espaco.e16,
                        Espaco.e16,
                      ),
                      child: ExcludeSemantics(child: _LinhaAvanco(avanco)),
                    ),
            ),
            // O rodapé da folha, como a faixa de baixo de um carimbo: duas
            // células separadas por traço.
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: c.grade, width: Traco.fino),
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _Celula(
                        rotulo: 'Término previsto',
                        valor: termino,
                      ),
                    ),
                    VerticalDivider(
                      width: Traco.fino,
                      thickness: Traco.fino,
                      color: c.grade,
                    ),
                    Expanded(
                      child: _Celula(rotulo: 'Orçamento', valor: orcamento),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A linha do avanço entra crescendo quando o cronograma chega. Com
/// "reduzir animações" entra pronta: o AnimatedSize com duração zero se
/// remarca no próprio layout e o Flutter reclama.
class _CrescerSuave extends StatelessWidget {
  const _CrescerSuave({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duracao = context.duracao(Movimento.medio);
    if (duracao == Duration.zero) return child;
    return AnimatedSize(
      duration: duracao,
      curve: Movimento.entrar,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

/// Onde a obra está: a fase atual (a primeira começada e não terminada;
/// se nenhuma, a primeira que falta) e o avanço físico, de 0 a 100.
class _Avanco {
  const _Avanco(this.fase, this.percentual);

  /// Nulo: sem cronograma.
  final String? fase;
  final int percentual;

  /// Nulo enquanto o cronograma carrega.
  static _Avanco? de(List<CronogramaFaseModel>? cronograma) {
    if (cronograma == null) return null;
    if (cronograma.isEmpty) return const _Avanco(null, 0);
    final fases = [...cronograma]..sort((a, b) => a.ordem.compareTo(b.ordem));
    final atual = fases
            .where(
                (f) => f.percentualConcluido > 0 && f.percentualConcluido < 100)
            .firstOrNull ??
        fases.where((f) => f.percentualConcluido < 100).firstOrNull;
    final percentual = ProgressoMaquete.doCronograma(fases).percentualObra;
    return _Avanco(atual?.nome ?? 'Fases concluídas', percentual);
  }

  String get semantica => fase == null
      ? 'sem cronograma'
      : 'fase $fase, $percentual% da obra';
}

class _LinhaAvanco extends StatelessWidget {
  const _LinhaAvanco(this.avanco);

  final _Avanco avanco;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final fase = avanco.fase;
    if (fase == null) {
      return Text(
        'Sem cronograma',
        style: Tipografia.apoio.copyWith(color: c.grafite2),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ParComValor(
          esquerda: Text(
            fase,
            style: Tipografia.corpoForte.copyWith(color: c.grafite),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          direita: Text(
            '${avanco.percentual}%',
            style: Tipografia.subtitulo.copyWith(
              color: c.grafite,
              fontFeatures: Tipografia.tabular,
            ),
          ),
        ),
        const SizedBox(height: Espaco.e8),
        ReguaCota(valor: avanco.percentual / 100),
      ],
    );
  }
}

class _Celula extends StatelessWidget {
  const _Celula({required this.rotulo, required this.valor});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Espaco.e16,
        Espaco.e12,
        Espaco.e12,
        Espaco.e12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Rotulo(rotulo),
          const SizedBox(height: Espaco.e4),
          Text(
            valor,
            style: Tipografia.subtitulo.copyWith(
              color: c.grafite,
              fontFeatures: Tipografia.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lembrete de confirmação de e-mail para quem já trabalha na obra.
class _AvisoEmailPendente extends StatefulWidget {
  const _AvisoEmailPendente();

  @override
  State<_AvisoEmailPendente> createState() => _AvisoEmailPendenteState();
}

class _AvisoEmailPendenteState extends State<_AvisoEmailPendente> {
  bool _enviando = false;

  Future<void> _reenviar() async {
    setState(() => _enviando = true);
    final auth = context.read<AuthProvider>();
    final erro = await auth.reenviarVerificacao();
    // Se o link já tiver sido clicado, a faixa some sozinha.
    await auth.atualizarVerificacao();
    if (!mounted) return;
    setState(() => _enviando = false);
    mostrarAviso(
      context,
      erro ?? 'E-mail de confirmação enviado. Olhe no spam também.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Folha(
      preenchimento: const EdgeInsets.fromLTRB(
        Espaco.e16,
        Espaco.e12,
        Espaco.e8,
        Espaco.e8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.mark_email_unread_outlined,
                    color: c.grafite),
              ),
              const SizedBox(width: Espaco.e12),
              Expanded(
                child: Text(
                  'Confirme seu e-mail para conseguir recuperar a conta se '
                  'esquecer a senha.',
                  style: Tipografia.corpo.copyWith(color: c.grafite),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _enviando ? null : () => unawaited(_reenviar()),
              child: Text(_enviando ? 'Enviando…' : 'Reenviar e-mail'),
            ),
          ),
        ],
      ),
    );
  }
}
