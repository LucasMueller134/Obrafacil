import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../design/maquete/maquete.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';

/// Porta de entrada de quem contratou a obra: lista as obras que ele
/// acompanha, com a fase e o avanço. Nenhum dado financeiro passa por aqui.
class ClienteObrasScreen extends StatelessWidget {
  const ClienteObrasScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const TemaPrancheta(child: _ObrasDoCliente());
}

class _ObrasDoCliente extends StatefulWidget {
  const _ObrasDoCliente();

  @override
  State<_ObrasDoCliente> createState() => _ObrasDoClienteState();
}

class _ObrasDoClienteState extends State<_ObrasDoCliente> {
  Stream<List<ObraModel>>? _obras;
  String? _cliente;

  Stream<List<ObraModel>> _obrasDe(String usuarioId) {
    if (_obras == null || _cliente != usuarioId) {
      _cliente = usuarioId;
      _obras = context.read<FirestoreService>().obrasDoCliente(usuarioId);
    }
    return _obras!;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final usuario = context.watch<AuthProvider>().usuario;
    if (usuario == null) {
      return const Scaffold(
        body: Center(child: IndicadorCarregando()),
      );
    }
    final primeiroNome = usuario.nome.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      appBar: AppBar(
        actions: [
          // "Sair" no menu, longe do polegar.
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
        builder: (context, snapshot) {
          final carregando =
              snapshot.connectionState == ConnectionState.waiting;
          final obras = snapshot.data ?? const <ObraModel>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e32),
            children: [
              const Rotulo('Acompanhamento'),
              const SizedBox(height: Espaco.e4),
              Semantics(
                header: true,
                child: Text(
                  primeiroNome.isEmpty ? 'Minhas obras' : 'Olá, $primeiroNome',
                  style: Tipografia.tituloTela.copyWith(color: c.grafite),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: Espaco.e24),
              if (carregando)
                const EsqueletoFolha(rotuloSemantico: 'Buscando suas obras')
              else if (snapshot.hasError)
                const AvisoVazio(
                  icone: Icons.cloud_off_outlined,
                  titulo: 'As obras não carregaram',
                  texto: 'Confira a internet e abra o app de novo.',
                )
              else if (obras.isEmpty)
                const AvisoVazio(
                  icone: Icons.holiday_village_outlined,
                  titulo: 'Nenhuma obra por aqui ainda',
                  texto: 'Peça ao responsável pela obra o código de '
                      'acompanhamento e toque em "Entrar com código", aqui '
                      'embaixo.',
                )
              else ...[
                Semantics(
                  header: true,
                  container: true,
                  child: LinhaCota(
                    legenda:
                        obras.length == 1 ? '1 obra' : '${obras.length} obras',
                  ),
                ),
                const SizedBox(height: Espaco.e16),
                for (var i = 0; i < obras.length; i++) ...[
                  if (i > 0) const SizedBox(height: Espaco.e12),
                  _FolhaObraCliente(obra: obras[i]),
                ],
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: BarraDeAcao(
        principal: BotaoPrincipal(
          rotulo: 'Entrar com código',
          icone: Icons.vpn_key_outlined,
          grande: true,
          expandir: true,
          aoTocar: () => unawaited(_entrarComCodigo(context)),
        ),
      ),
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
        title: const Text('Acompanhar uma obra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Digite o código de acompanhamento que o responsável pela obra '
              'passou para você.',
              style: Tipografia.apoio.copyWith(color: ctx.cores.grafite2),
            ),
            const SizedBox(height: Espaco.e12),
            TextField(
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
                labelText: 'Código',
                hintText: 'A3B7XZ',
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
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
    // Sem dispose: o campo ainda está na tela na animação de saída.
    if (codigo == null || codigo.trim().isEmpty || !context.mounted) return;

    final db = context.read<FirestoreService>();
    final uid = context.read<AuthProvider>().usuario!.id;
    final obra = await db.entrarComoClientePorCodigo(codigo, uid);
    if (!context.mounted) return;
    unawaited(obra == null ? Tato.erro() : Tato.confirmar());
    mostrarAviso(
      context,
      obra == null
          ? 'Código não encontrado. Confira com o responsável pela obra.'
          : 'Pronto! Agora você acompanha a ${obra.nome}.',
    );
  }
}

/// Uma obra do cliente: nome, endereço, a fase e o avanço (a mesma conta
/// da área do cliente) e a entrega prevista. Tocar abre o acompanhamento.
class _FolhaObraCliente extends StatefulWidget {
  const _FolhaObraCliente({required this.obra});

  final ObraModel obra;

  @override
  State<_FolhaObraCliente> createState() => _FolhaObraClienteState();
}

class _FolhaObraClienteState extends State<_FolhaObraCliente> {
  late Stream<List<CronogramaFaseModel>> _cronograma =
      context.read<FirestoreService>().cronograma(widget.obra.id);

  @override
  void didUpdateWidget(_FolhaObraCliente antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.obra.id != widget.obra.id) {
      _cronograma = context.read<FirestoreService>().cronograma(widget.obra.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final obra = widget.obra;
    final entrega = Formatters.data(obra.previsaoTermino);
    final selo = switch (obra.status) {
      StatusObra.emAndamento => null,
      StatusObra.pausada =>
        const SeloStatus(StatusSelo.aviso, texto: 'Obra pausada'),
      StatusObra.concluida =>
        const SeloStatus(StatusSelo.aprovado, texto: 'Obra concluída'),
    };
    return StreamBuilder<List<CronogramaFaseModel>>(
      stream: _cronograma,
      builder: (context, snap) {
        final fases = [...?(snap.hasError ? null : snap.data)]
          ..sort((a, b) => a.ordem.compareTo(b.ordem));
        final atual = fases
                .where((f) =>
                    f.percentualConcluido > 0 && f.percentualConcluido < 100)
                .firstOrNull ??
            fases.where((f) => f.percentualConcluido < 100).firstOrNull;
        final percentual = ProgressoMaquete.doCronograma(fases).percentualObra;
        return AreaPressionavel(
          aoTocar: () => context.push('/cliente/${obra.id}'),
          vibrar: true,
          rotuloSemantico: [
            obra.nome,
            if (selo != null) obra.status.label,
            obra.endereco,
            if (fases.isNotEmpty)
              'fase ${atual?.nome ?? 'concluída'}, $percentual% da obra',
            'entrega prevista $entrega',
          ].join(', '),
          construtor: (context, e) => Folha(
            cor: e.pressionado ? c.folhaRebaixada : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(obra.nome,
                              style:
                                  Tipografia.titulo.copyWith(color: c.grafite),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: Espaco.e4),
                          Text(obra.endereco,
                              style:
                                  Tipografia.apoio.copyWith(color: c.grafite2),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          if (selo != null) ...[
                            const SizedBox(height: Espaco.e12),
                            selo,
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: c.traco),
                  ],
                ),
                if (fases.isNotEmpty) ...[
                  const SizedBox(height: Espaco.e16),
                  ExcludeSemantics(
                    child: ParComValor(
                      esquerda: Text(atual?.nome ?? 'Fases concluídas',
                          style:
                              Tipografia.corpoForte.copyWith(color: c.grafite),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      direita: Text('$percentual%',
                          style: Tipografia.subtitulo.copyWith(
                              color: c.grafite,
                              fontFeatures: Tipografia.tabular)),
                    ),
                  ),
                  const SizedBox(height: Espaco.e8),
                  ExcludeSemantics(child: ReguaCota(valor: percentual / 100)),
                ],
                const SizedBox(height: Espaco.e12),
                Row(
                  children: [
                    Icon(Icons.event_outlined, size: 20, color: c.grafite2),
                    const SizedBox(width: Espaco.e4),
                    Text('Entrega prevista: $entrega',
                        style: Tipografia.apoio.copyWith(
                            color: c.grafite2,
                            fontFeatures: Tipografia.tabular)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
