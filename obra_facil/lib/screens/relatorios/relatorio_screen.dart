import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/perguntas_obra_service.dart';
import '../../services/ia/relatorio_semanal_service.dart';
import '../../services/ia/voz_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/animacoes.dart';
import '../../widgets/carregando_obra.dart';

/// Relatórios da obra: a análise semanal gerada no aparelho e o
/// assistente de perguntas (chat) sobre os dados da obra.
class RelatorioScreen extends StatefulWidget {
  final String obraId;

  const RelatorioScreen({super.key, required this.obraId});

  @override
  State<RelatorioScreen> createState() => _RelatorioScreenState();
}

class _RelatorioScreenState extends State<RelatorioScreen> {
  RelatorioSemanal? _relatorio;
  DadosObraChat? _dados;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _gerar();
  }

  Future<void> _gerar() async {
    setState(() {
      _relatorio = null;
      _dados = null;
      _erro = null;
    });
    try {
      final db = context.read<FirestoreService>();
      final obra = await db.obra(widget.obraId).first;
      if (obra == null) throw Exception('Obra não encontrada');
      final lancamentos = await db.lancamentos(widget.obraId).first;
      final diario = await db.diario(widget.obraId).first;
      final cronograma = await db.cronograma(widget.obraId).first;
      final estoque = await db.estoque(widget.obraId).first;
      final movimentos = await db.movimentos(widget.obraId).first;

      final dados = DadosObraChat(
        obra: obra,
        lancamentos: lancamentos,
        diario: diario,
        cronograma: cronograma,
        estoque: estoque,
        movimentos: movimentos,
      );
      final relatorio = RelatorioSemanalService.gerar(
        obra: obra,
        lancamentos: lancamentos,
        diario: diario,
        cronograma: cronograma,
        estoque: estoque,
        movimentos: movimentos,
      );
      if (mounted) {
        setState(() {
          _dados = dados;
          _relatorio = relatorio;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    }
  }

  IconData _icone(TipoSecao tipo) => switch (tipo) {
        TipoSecao.visaoGeral => Icons.apartment,
        TipoSecao.financeiro => Icons.payments,
        TipoSecao.pendencias => Icons.hourglass_top,
        TipoSecao.estoque => Icons.inventory_2,
        TipoSecao.canteiro => Icons.engineering,
        TipoSecao.previsao => Icons.query_stats,
      };

  @override
  Widget build(BuildContext context) {
    final r = _relatorio;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Relatórios'),
          actions: [
            IconButton(
              tooltip: 'Gerar novamente',
              icon: const Icon(Icons.refresh),
              onPressed: _gerar,
            ),
            if (r != null)
              IconButton(
                tooltip: 'Compartilhar análise',
                icon: const Icon(Icons.share),
                onPressed: () => Share.share(r.textoCompartilhavel),
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.assessment, size: 20), text: 'Análise'),
              Tab(icon: Icon(Icons.forum, size: 20), text: 'Perguntar'),
            ],
          ),
        ),
        body: _erro != null
            ? Center(child: Text('Erro ao carregar: $_erro'))
            : (r == null || _dados == null)
                ? const CarregandoObra(mensagem: 'Cruzando os dados da obra…')
                : TabBarView(
                    children: [
                      _analise(r),
                      _ChatObra(dados: _dados!),
                    ],
                  ),
      ),
    );
  }

  Widget _analise(RelatorioSemanal r) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      children: [
        Text(
          r.nomeObra,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ).aparecerSecao(0),
        const SizedBox(height: 2),
        Text(
          'Análise gerada no aparelho em ${Formatters.data(r.geradoEm)}, '
          'cruzando lançamentos, diário, cronograma e estoque.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textoSecundario),
        ).aparecerSecao(0),
        const SizedBox(height: 16),
        for (final (i, secao) in r.secoes.indexed) ...[
          _CartaoSecao(
            icone: _icone(secao.tipo),
            titulo: secao.titulo,
            paragrafos: secao.paragrafos,
          ).aparecerSecao(i + 1),
          const SizedBox(height: 12),
        ],
        _CartaoAcoes(acoes: r.acoes).aparecerSecao(r.secoes.length + 1),
      ],
    );
  }
}

// ================================================================== Chat

class _MsgChat {
  final String texto;
  final bool deUsuario;
  final List<String> sugestoes;

  const _MsgChat(this.texto,
      {required this.deUsuario, this.sugestoes = const []});
}

class _ChatObra extends StatefulWidget {
  final DadosObraChat dados;

  const _ChatObra({required this.dados});

  @override
  State<_ChatObra> createState() => _ChatObraState();
}

class _ChatObraState extends State<_ChatObra>
    with AutomaticKeepAliveClientMixin {
  final _campoCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _voz = VozService();
  bool _ouvindoVoz = false;
  late final List<_MsgChat> _mensagens = [
    _MsgChat(
      'Oi! Sou o assistente da ${widget.dados.obra.nome}. Pergunte '
      'qualquer coisa sobre gastos, estoque, orçamento, cronograma ou '
      'equipe — respondo com os dados reais da obra, sem internet. 👷',
      deUsuario: false,
      sugestoes: PerguntasObraService.sugestoesIniciais,
    ),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _campoCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _enviar(String texto) {
    final pergunta = texto.trim();
    if (pergunta.isEmpty) return;
    final resposta =
        PerguntasObraService.responder(pergunta, widget.dados);
    setState(() {
      _mensagens.add(_MsgChat(pergunta, deUsuario: true));
      _mensagens.add(_MsgChat(resposta.texto,
          deUsuario: false, sugestoes: resposta.sugestoes));
      _campoCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _falar() async {
    if (_ouvindoVoz) {
      await _voz.parar();
      setState(() => _ouvindoVoz = false);
      return;
    }
    final ok = await _voz.inicializar();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Microfone indisponível — verifique a permissão.')));
      return;
    }
    setState(() => _ouvindoVoz = true);
    await _voz.ouvir((texto, finalizou) {
      if (!mounted) return;
      setState(() {
        _campoCtrl.text = texto;
        if (finalizou) _ouvindoVoz = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: _mensagens.length,
            itemBuilder: (_, i) {
              final msg = _mensagens[i];
              return _Bolha(
                msg: msg,
                mostrarSugestoes: i == _mensagens.length - 1,
                onSugestao: _enviar,
              )
                  .animate()
                  .fadeIn(duration: 220.ms)
                  .slideY(begin: 0.08, end: 0, duration: 260.ms);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: _ouvindoVoz ? 'Parar' : 'Perguntar por voz',
                  onPressed: _falar,
                  style: IconButton.styleFrom(
                    backgroundColor: _ouvindoVoz
                        ? AppColors.erro.withValues(alpha: 0.25)
                        : AppColors.superficieAlta,
                  ),
                  icon: Icon(
                    _ouvindoVoz ? Icons.stop : Icons.mic,
                    color:
                        _ouvindoVoz ? AppColors.erro : AppColors.laranja,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _campoCtrl,
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: _enviar,
                    decoration: InputDecoration(
                      hintText: _ouvindoVoz
                          ? 'Ouvindo…'
                          : 'Pergunte sobre a obra…',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Enviar',
                  onPressed: () => _enviar(_campoCtrl.text),
                  style: IconButton.styleFrom(
                      backgroundColor: AppColors.laranja),
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bolha extends StatelessWidget {
  final _MsgChat msg;
  final bool mostrarSugestoes;
  final void Function(String) onSugestao;

  const _Bolha({
    required this.msg,
    required this.mostrarSugestoes,
    required this.onSugestao,
  });

  @override
  Widget build(BuildContext context) {
    final bolha = Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: msg.deUsuario ? AppColors.laranja : AppColors.superficie,
        border:
            msg.deUsuario ? null : Border.all(color: AppColors.borda),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(msg.deUsuario ? 16 : 4),
          bottomRight: Radius.circular(msg.deUsuario ? 4 : 16),
        ),
      ),
      child: Text(
        msg.texto,
        style: TextStyle(
          color: msg.deUsuario ? Colors.white : AppColors.textoPrimario,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: msg.deUsuario
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: msg.deUsuario
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!msg.deUsuario) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.laranja,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.engineering,
                      size: 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(child: bolha),
            ],
          ),
          if (mostrarSugestoes && msg.sugestoes.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                  top: 8, left: msg.deUsuario ? 0 : 36),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in msg.sugestoes)
                    ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      avatar: const Icon(Icons.bolt,
                          size: 14, color: AppColors.amareloCapacete),
                      onPressed: () => onSugestao(s),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================ Análise

class _CartaoSecao extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final List<String> paragrafos;

  const _CartaoSecao({
    required this.icone,
    required this.titulo,
    required this.paragrafos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 18, color: AppColors.laranja),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final (i, p) in paragrafos.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            Text(
              p,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartaoAcoes extends StatelessWidget {
  final List<String> acoes;

  const _CartaoAcoes({required this.acoes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.laranja.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.laranja.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist, size: 18, color: AppColors.laranja),
              const SizedBox(width: 8),
              Text(
                'O que fazer agora',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final acao in acoes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.arrow_right,
                        size: 18, color: AppColors.laranja),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      acao,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
