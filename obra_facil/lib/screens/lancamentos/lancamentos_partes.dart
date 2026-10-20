// Peças visuais da fila de aprovação (lancamentos_screen.dart), no
// desenho da prancheta. Só desenho: o que acontece ao tocar é a tela que
// decide e passa por parâmetro.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design/design.dart';
import '../../models/models.dart';
import '../../utils/formatters.dart';
import '../../widgets/imagem_obra.dart';

/// Como o gasto chegou, em palavras de canteiro (sem "OCR").
(IconData, String) origemDoGasto(OrigemLancamento origem) => switch (origem) {
      OrigemLancamento.ocr => (Icons.document_scanner_outlined, 'foto da nota'),
      OrigemLancamento.voz => (Icons.mic_none, 'voz'),
      OrigemLancamento.manual => (Icons.edit_outlined, 'manual'),
    };

/// O selo de status (forma + texto) de um lançamento.
StatusSelo seloDoStatus(StatusLancamento status) => switch (status) {
      StatusLancamento.pendente => StatusSelo.pendente,
      StatusLancamento.aprovado => StatusSelo.aprovado,
      StatusLancamento.rejeitado => StatusSelo.recusado,
    };

final NumberFormat _quantidade = NumberFormat('#,##0.##', 'pt_BR');

/// "2.000 un Bloco cerâmico 9 furos": a quantidade com separador de
/// milhar, para ler de relance.
String resumoDoItem(ItemMaterialModel item) =>
    '${_quantidade.format(item.quantidade)} ${item.unidade} ${item.material}';

/// O que entra no estoque, sem repetir o nome quando o material é o
/// próprio gasto ("Areia média" → "6 m³").
String resumoDosItens(LancamentoModel l) {
  final descricao = l.descricao.trim().toLowerCase();
  return l.itens.map((item) {
    if (item.material.trim().toLowerCase() == descricao) {
      return '${_quantidade.format(item.quantidade)} ${item.unidade}';
    }
    return resumoDoItem(item);
  }).join(' · ');
}

/// "Casa do Construtor · 14/10": fornecedor (quando há) e data. Com
/// [emLinhas], um embaixo do outro, a data em cima: na linha de lista, ao
/// lado do selo, os dois juntos não cabem em 390 dp (e a quebra deixava o
/// ponto sobrando). O apoio da linha tem no máximo 2 linhas; com a data
/// primeiro, um fornecedor comprido ou a fonte grande cortam o nome com
/// reticências, nunca a data.
String fornecedorEData(LancamentoModel l, {bool emLinhas = false}) {
  final fornecedor = l.fornecedorNome?.trim() ?? '';
  final data = Formatters.dataCurta(l.data);
  if (fornecedor.isEmpty) return data;
  return emLinhas ? '$data\n$fornecedor' : '$fornecedor · $data';
}

/// Valor em R$ com os centavos menores (o olho lê os reais primeiro) e
/// algarismos tabulares. Se não couber, diminui; nunca corta dígito.
class TextoValor extends StatelessWidget {
  const TextoValor(
    this.valor, {
    super.key,
    this.estilo = Tipografia.tituloTela,
    this.cor,
  });

  final double valor;
  final TextStyle estilo;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final texto = Formatters.moeda(valor);
    final virgula = texto.lastIndexOf(',');
    final base = estilo.copyWith(color: cor ?? context.cores.grafite);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        virgula < 0
            ? TextSpan(text: texto)
            : TextSpan(children: [
                TextSpan(text: texto.substring(0, virgula)),
                TextSpan(
                  text: texto.substring(virgula),
                  style: TextStyle(fontSize: estilo.fontSize! * 0.6),
                ),
              ]),
        style: base,
        maxLines: 1,
        softWrap: false,
        semanticsLabel: texto,
      ),
    );
  }
}

/// Texto de apoio com um ícone de traço antes ("[mic] voz").
class _ComIcone extends StatelessWidget {
  const _ComIcone({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Text.rich(
      TextSpan(children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: Espaco.e4),
            child: Icon(icone, size: 20, color: c.grafite2),
          ),
        ),
        TextSpan(text: texto),
      ]),
      style: Tipografia.apoio.copyWith(color: c.grafite2),
    );
  }
}

/// Topo da fila do dono: a amostra de hachura (pendente), quantos são e
/// quanto somam (o valor principal da tela) e, com dois ou mais, o
/// "Aprovar todos".
class CabecalhoPendentes extends StatelessWidget {
  const CabecalhoPendentes({
    super.key,
    required this.quantidade,
    required this.total,
    this.aoAprovarTodos,
  });

  final int quantidade;
  final double total;

  /// Nulo: sem o botão (um gasto só, o cartão já tem o Aprovar).
  final VoidCallback? aoAprovarTodos;

  @override
  Widget build(BuildContext context) {
    final rotulo =
        quantidade == 1 ? '1 gasto para aprovar' : '$quantidade gastos para aprovar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const CaixaHachurada(largura: 16, altura: 60),
            const SizedBox(width: Espaco.e12),
            Expanded(child: ValorHeroi(valor: total, rotulo: rotulo)),
          ],
        ),
        if (aoAprovarTodos != null) ...[
          const SizedBox(height: Espaco.e16),
          BotaoContorno(
            rotulo: 'Aprovar todos',
            icone: Icons.done_all,
            expandir: true,
            // A tela vibra ao aprovar (Tato.confirmar).
            vibrar: false,
            aoTocar: aoAprovarTodos,
          ),
        ],
      ],
    );
  }
}

/// Cabeçalho das listas que não são a fila: um rótulo, o valor somado e,
/// opcional, uma linha de apoio.
class CabecalhoLista extends StatelessWidget {
  const CabecalhoLista({
    super.key,
    required this.rotulo,
    required this.total,
    this.apoio,
  });

  final String rotulo;
  final double total;
  final String? apoio;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ValorHeroi(valor: total, rotulo: rotulo),
        if (apoio != null) ...[
          const SizedBox(height: Espaco.e4),
          Text(apoio!, style: Tipografia.apoio.copyWith(color: c.grafite2)),
        ],
      ],
    );
  }
}

/// Cartão de um gasto pendente para o dono: a foto da nota (quando há),
/// o que é, de quem, quando e como chegou, o valor grande, o que entra no
/// estoque e as duas decisões. A margem hachurada à esquerda é a marca de
/// "pendente" da prancheta (forma, não só cor).
class CartaoPendente extends StatelessWidget {
  const CartaoPendente({
    super.key,
    required this.lancamento,
    required this.aoAbrir,
    required this.aoAprovar,
    required this.aoRecusar,
  });

  final LancamentoModel lancamento;
  final VoidCallback aoAbrir;
  final VoidCallback aoAprovar;
  final VoidCallback aoRecusar;

  /// Largura da margem hachurada.
  static const double margemPendente = 12;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final l = lancamento;
    final (iconeOrigem, origem) = origemDoGasto(l.origem);
    final foto = l.fotoNotaUrl;

    // O leitor de tela ouve também o status, que na tela é a margem
    // hachurada (forma, sem texto no cartão).
    final leitura = [
      l.descricao,
      'pendente',
      Formatters.moeda(l.valor),
      fornecedorEData(l),
      origem,
      if (l.itens.isNotEmpty) 'entra no estoque: ${resumoDosItens(l)}',
    ].join(', ');

    final informacao = AreaPressionavel(
      aoTocar: aoAbrir,
      escala: 1,
      rotuloSemantico: leitura,
      dicaSemantica: 'Abre os detalhes do gasto',
      construtor: (context, e) => AnimatedContainer(
        duration: context.duracao(Movimento.rapido),
        color: e.pressionado ? c.folhaRebaixada : c.folha,
        foregroundDecoration: e.focado
            ? BoxDecoration(border: Border.all(color: c.marcaTexto, width: 3))
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (foto != null)
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: c.folhaRebaixada,
                  border: Border(
                    bottom: BorderSide(color: c.grafite, width: Traco.fino),
                  ),
                ),
                child: ExcludeSemantics(child: ImagemObra(foto)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaco.e16,
                Espaco.e16,
                Espaco.e8,
                Espaco.e12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l.descricao,
                          style:
                              Tipografia.corpoForte.copyWith(color: c.grafite),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: Espaco.e4),
                        // Fornecedor e data; a origem (ícone + texto) é um
                        // bloco só: se não couber, desce inteira. O ícone
                        // separa os dois, sem ponto sobrando no fim da linha.
                        Wrap(
                          spacing: Espaco.e12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              fornecedorEData(l),
                              style:
                                  Tipografia.apoio.copyWith(color: c.grafite2),
                            ),
                            _ComIcone(icone: iconeOrigem, texto: origem),
                          ],
                        ),
                        const SizedBox(height: Espaco.e8),
                        TextoValor(l.valor),
                        if (l.itens.isNotEmpty) ...[
                          const SizedBox(height: Espaco.e8),
                          _ComIcone(
                            icone: Icons.move_to_inbox_outlined,
                            texto: 'Entra no estoque: ${resumoDosItens(l)}',
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: Espaco.e4),
                    child: Icon(Icons.chevron_right, size: 28, color: c.traco),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final acoes = Padding(
      padding: const EdgeInsets.fromLTRB(
        Espaco.e16,
        Espaco.e4,
        Espaco.e16,
        Espaco.e16,
      ),
      child: ParDeDecisao(aoAprovar: aoAprovar, aoRecusar: aoRecusar),
    );

    return Folha(
      destaque: true,
      preenchimento: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: margemPendente,
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.folha,
                  border: Border(
                    right: BorderSide(color: c.grafite, width: Traco.fino),
                  ),
                ),
                child: CustomPaint(
                  painter: Hachura(cor: c.grafite, espacamento: 5),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: margemPendente),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [informacao, acoes],
            ),
          ),
        ],
      ),
    );
  }
}

/// [Aprovar] e [Recusar] lado a lado; se um dos rótulos não couber na
/// metade da largura (360 dp com a fonte do sistema maior), um embaixo do
/// outro, com a largura toda. Sem isso o botão da prancheta, que quebra o
/// rótulo em até 2 linhas, cortava a palavra no meio ("Aprov / ar").
class ParDeDecisao extends StatelessWidget {
  const ParDeDecisao({
    super.key,
    required this.aoAprovar,
    required this.aoRecusar,
    this.grande = false,
  });

  final VoidCallback aoAprovar;
  final VoidCallback aoRecusar;

  /// 72 dp (a decisão da folha de detalhe); senão 64.
  final bool grande;

  static const String _aprovar = 'Aprovar';
  static const String _recusar = 'Recusar';

  /// Largura que o botão da prancheta pede para o [rotulo] numa linha só:
  /// o texto (no tamanho da fonte do sistema), o ícone de 24 com 8 de
  /// folga, o recuo de cada lado (16, ou 24 no [grande]) e, no contorno, a
  /// borda de 2. São as medidas de `design/componentes/botoes.dart`.
  static double _largura(
    BuildContext context,
    String rotulo, {
    required bool grande,
    required bool contorno,
  }) {
    final pintor = TextPainter(
      text: TextSpan(
        text: rotulo,
        style: Tipografia.subtitulo.copyWith(height: 1.2),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final texto = pintor.width;
    pintor.dispose();
    const icone = 24 + Espaco.e8;
    final recuo = 2 * (grande ? Espaco.e24 : Espaco.e16);
    final borda = contorno ? 2 * Traco.forte : 0;
    // Meio ponto de folga para o arredondamento do layout.
    return texto + icone + recuo + borda + 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final aprovar = BotaoPrincipal(
      rotulo: _aprovar,
      icone: Icons.check,
      grande: grande,
      expandir: true,
      // A tela vibra ao aprovar (Tato.confirmar).
      vibrar: false,
      aoTocar: aoAprovar,
    );
    final recusar = BotaoContorno(
      rotulo: _recusar,
      icone: Icons.close,
      grande: grande,
      expandir: true,
      aoTocar: aoRecusar,
    );
    return LayoutBuilder(builder: (context, limites) {
      final metade = (limites.maxWidth - Espaco.entreAlvos) / 2;
      final cabe =
          _largura(context, _aprovar, grande: grande, contorno: false) <=
                  metade &&
              _largura(context, _recusar, grande: grande, contorno: true) <=
                  metade;
      if (cabe) {
        return Row(
          children: [
            Expanded(child: aprovar),
            const SizedBox(width: Espaco.entreAlvos),
            Expanded(child: recusar),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          aprovar,
          const SizedBox(height: Espaco.entreAlvos),
          recusar,
        ],
      );
    });
  }
}

/// O que aparece atrás do cartão ao deslizar (o atalho dos botões):
/// para a direita aprova (grafite, como o botão Aprovar), para a esquerda
/// recusa (contorno vermelho de revisão, como o Recusar). Cor sólida,
/// ícone e texto.
class FundoDeslize extends StatelessWidget {
  const FundoDeslize.aprovar({super.key}) : aprovar = true;
  const FundoDeslize.recusar({super.key}) : aprovar = false;

  final bool aprovar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final frente = aprovar ? c.sobreGrafite : c.grafite;
    final icone = Icon(
      aprovar ? Icons.check : Icons.close,
      size: 32,
      color: aprovar ? c.sobreGrafite : c.revisao,
    );
    final texto = Text(
      aprovar ? 'Aprovar' : 'Recusar',
      style: Tipografia.titulo.copyWith(color: frente),
    );
    return Container(
      alignment: aprovar ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: Espaco.e24),
      decoration: BoxDecoration(
        color: aprovar ? c.grafite : c.folha,
        borderRadius: Raio.cantoPadrao,
        border: aprovar
            ? null
            : Border.all(color: c.revisao, width: Traco.forte),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: aprovar
            ? [icone, const SizedBox(width: Espaco.e8), texto]
            : [texto, const SizedBox(width: Espaco.e8), icone],
      ),
    );
  }
}

/// Um trecho da folha que agrupa a lista: a primeira linha leva o topo
/// da borda, a última o fundo; juntas parecem uma folha só, mas a lista
/// continua montando só o que está à vista.
class TrechoDeLista extends StatelessWidget {
  const TrechoDeLista({
    super.key,
    required this.primeiro,
    required this.ultimo,
    required this.child,
  });

  final bool primeiro;
  final bool ultimo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final lado = BorderSide(color: c.traco, width: Traco.fino);
    const raio = Radius.circular(Raio.padrao);
    return Container(
      padding: EdgeInsets.only(
        left: Traco.fino,
        right: Traco.fino,
        top: primeiro ? Traco.fino : 0,
        bottom: ultimo ? Traco.fino : 0,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.folha,
        border: Border(
          top: primeiro ? lado : BorderSide.none,
          bottom: ultimo ? lado : BorderSide.none,
          left: lado,
          right: lado,
        ),
        borderRadius: BorderRadius.vertical(
          top: primeiro ? raio : Radius.zero,
          bottom: ultimo ? raio : Radius.zero,
        ),
      ),
      child: child,
    );
  }
}

/// Lista vazia (ou fila zerada): ícone de traço, o que aconteceu e, se
/// houver, o que fazer.
class AvisoVazio extends StatelessWidget {
  const AvisoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.texto,
    this.acao,
  });

  final IconData icone;
  final String titulo;
  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Folha(
      preenchimento: const EdgeInsets.all(Espaco.e24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 36, color: c.grafite),
          const SizedBox(height: Espaco.e12),
          Text(titulo, style: Tipografia.titulo.copyWith(color: c.grafite)),
          const SizedBox(height: Espaco.e4),
          Text(texto, style: Tipografia.corpo.copyWith(color: c.grafite2)),
          if (acao != null) ...[
            const SizedBox(height: Espaco.e24),
            acao!,
          ],
        ],
      ),
    );
  }
}

/// A folha de detalhe de um gasto: a foto da nota grande no topo, o que
/// é, o status, o valor grande e o resto num carimbo de prancha. As
/// [acoes] (aprovar/recusar, excluir) ficam fixas no rodapé da folha.
class FolhaDetalhe extends StatelessWidget {
  const FolhaDetalhe({super.key, required this.lancamento, this.acoes});

  final LancamentoModel lancamento;
  final Widget? acoes;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final l = lancamento;
    final (_, origem) = origemDoGasto(l.origem);
    final foto = l.fotoNotaUrl;
    final seguro = MediaQuery.viewPaddingOf(context).bottom;
    // A nota grande, mas sem empurrar o valor para fora da folha numa tela
    // baixa (360 x 640: as decisões empilhadas tomam o rodapé).
    final alturaFoto =
        (MediaQuery.sizeOf(context).height * 0.3).clamp(160.0, 240.0);
    final rotuloEstoque = switch (l.status) {
      StatusLancamento.pendente => 'Entra no estoque ao aprovar',
      StatusLancamento.aprovado => 'Entrou no estoque',
      StatusLancamento.rejeitado => 'Materiais',
    };

    final carimbo = Carimbo(linhas: [
      [
        CelulaCarimbo(rotulo: 'Categoria', valor: l.categoria.label),
        CelulaCarimbo(rotulo: 'Data', valor: Formatters.data(l.data)),
      ],
      [
        CelulaCarimbo(
          rotulo: 'Origem',
          valor: '${origem[0].toUpperCase()}${origem.substring(1)}',
        ),
        CelulaCarimbo(rotulo: 'Registrado por', valor: l.criadoPorNome),
      ],
      if (l.fornecedorNome != null)
        [CelulaCarimbo(rotulo: 'Fornecedor', valor: l.fornecedorNome!)],
      if (l.itens.isNotEmpty)
        [
          CelulaCarimbo(
            rotulo: rotuloEstoque,
            conteudo: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in l.itens)
                  Text(
                    resumoDoItem(item),
                    style: Tipografia.subtitulo.copyWith(color: c.grafite),
                  ),
              ],
            ),
          ),
        ],
      if (l.motivoRejeicao != null)
        [CelulaCarimbo(rotulo: 'Motivo da recusa', valor: l.motivoRejeicao!)],
    ]);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Espaco.margem,
                0,
                Espaco.margem,
                Espaco.e16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (foto != null) ...[
                    Container(
                      height: alturaFoto,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: c.folhaRebaixada,
                        borderRadius: Raio.cantoPadrao,
                        border: Border.all(color: c.grafite, width: Traco.fino),
                      ),
                      child: Semantics(
                        image: true,
                        label: 'Foto da nota',
                        child: ImagemObra(foto, fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: Espaco.e16),
                  ],
                  Text(
                    l.descricao,
                    style: Tipografia.titulo.copyWith(color: c.grafite),
                  ),
                  const SizedBox(height: Espaco.e8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SeloStatus(seloDoStatus(l.status)),
                  ),
                  const SizedBox(height: Espaco.e16),
                  ValorHeroi(valor: l.valor, rotulo: 'Valor'),
                  const SizedBox(height: Espaco.e16),
                  carimbo,
                ],
              ),
            ),
          ),
          if (acoes != null)
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.folha,
                border: Border(
                  top: BorderSide(color: c.grafite, width: Traco.fino),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  Espaco.margem,
                  Espaco.e12,
                  Espaco.margem,
                  Espaco.e12 + seguro,
                ),
                child: acoes,
              ),
            )
          else
            SizedBox(height: seguro),
        ],
      ),
    );
  }
}
