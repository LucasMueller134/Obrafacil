import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../design/design.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/perguntas_obra_service.dart';
import '../../services/ia/relatorio_semanal_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/chat_obra.dart';

/// Relatórios da obra: a análise semanal gerada no aparelho e o
/// assistente de perguntas (chat) sobre os dados da obra.
class RelatorioScreen extends StatelessWidget {
  final String obraId;

  const RelatorioScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) =>
      TemaPrancheta(child: _Relatorio(obraId: obraId));
}

class _Relatorio extends StatefulWidget {
  const _Relatorio({required this.obraId});

  final String obraId;

  @override
  State<_Relatorio> createState() => _RelatorioScreenState();
}

class _RelatorioScreenState extends State<_Relatorio> {
  /// 0: a análise; 1: perguntar (chat).
  int _aba = 0;
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
        TipoSecao.visaoGeral => Icons.apartment_outlined,
        TipoSecao.financeiro => Icons.payments_outlined,
        TipoSecao.pendencias => Icons.hourglass_top,
        TipoSecao.estoque => Icons.inventory_2_outlined,
        TipoSecao.canteiro => Icons.engineering_outlined,
        TipoSecao.previsao => Icons.query_stats,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final r = _relatorio;
    final dados = _dados;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Gerar novamente',
            icon: const Icon(Icons.refresh),
            onPressed: _gerar,
          ),
          if (r != null)
            IconButton(
              tooltip: 'Compartilhar análise',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => Share.share(r.textoCompartilhavel),
            ),
          const SizedBox(width: Espaco.e4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Rotulo('Relatórios'),
                const SizedBox(height: Espaco.e4),
                Semantics(
                  header: true,
                  child: Text(
                    r?.nomeObra ?? 'Obra',
                    style: Tipografia.tituloTela.copyWith(color: c.grafite),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: Espaco.e12),
                SeletorGrande<int>(
                  opcoes: const [
                    OpcaoSeletor(
                        valor: 0,
                        rotulo: 'Análise',
                        icone: Icons.assessment_outlined),
                    OpcaoSeletor(
                        valor: 1,
                        rotulo: 'Perguntar',
                        icone: Icons.forum_outlined),
                  ],
                  selecionado: _aba,
                  aoMudar: (v) => setState(() => _aba = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: _erro != null
                ? ListView(
                    padding: const EdgeInsets.all(Espaco.margem),
                    children: [
                      AvisoVazio(
                        icone: Icons.error_outline,
                        titulo: 'Não deu para montar o relatório',
                        texto: _erro!,
                        acao: BotaoContorno(
                          rotulo: 'Tentar de novo',
                          icone: Icons.refresh,
                          expandir: true,
                          aoTocar: () => unawaited(_gerar()),
                        ),
                      ),
                    ],
                  )
                : (r == null || dados == null)
                    ? ListView(
                        padding: const EdgeInsets.all(Espaco.margem),
                        children: const [
                          EsqueletoFolha(
                              linhas: 4,
                              rotuloSemantico: 'Cruzando os dados da obra'),
                        ],
                      )
                    : IndexedStack(
                        index: _aba,
                        children: [
                          _analise(r),
                          ChatObra(dados: dados),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _analise(RelatorioSemanal r) {
    final c = context.cores;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e32),
      children: [
        Text(
          'Análise gerada no aparelho em ${Formatters.data(r.geradoEm)}, '
          'cruzando lançamentos, diário, cronograma e estoque.',
          style: Tipografia.apoio.copyWith(color: c.grafite2),
        ),
        const SizedBox(height: Espaco.e16),
        _CartaoAcoes(acoes: r.acoes),
        for (final secao in r.secoes) ...[
          const SizedBox(height: Espaco.e24),
          _CartaoSecao(
            icone: _icone(secao.tipo),
            titulo: secao.titulo,
            paragrafos: secao.paragrafos,
          ),
        ],
      ],
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
    final c = context.cores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          container: true,
          child: LinhaCota(legenda: titulo),
        ),
        const SizedBox(height: Espaco.e12),
        Folha(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, size: 24, color: c.grafite),
              const SizedBox(width: Espaco.e12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, p) in paragrafos.indexed) ...[
                      if (i > 0) const SizedBox(height: Espaco.e8),
                      Text(p,
                          style: Tipografia.corpo.copyWith(color: c.grafite)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// O que fazer agora: a primeira coisa da análise, em destaque.
class _CartaoAcoes extends StatelessWidget {
  final List<String> acoes;

  const _CartaoAcoes({required this.acoes});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Folha(
      destaque: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist, size: 24, color: c.grafite),
              const SizedBox(width: Espaco.e8),
              Text('O que fazer agora',
                  style: Tipografia.subtitulo.copyWith(color: c.grafite)),
            ],
          ),
          const SizedBox(height: Espaco.e12),
          for (final (i, acao) in acoes.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Espaco.e4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}.',
                        style: Tipografia.corpoForte.copyWith(
                            color: c.marcaTexto,
                            fontFeatures: Tipografia.tabular)),
                  ),
                  Expanded(
                    child: Text(acao,
                        style: Tipografia.corpo.copyWith(color: c.grafite)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
