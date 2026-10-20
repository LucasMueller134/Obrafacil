part of 'novo_lancamento_screen.dart';

// Peças visuais do "Lançar gasto". Nenhuma delas fala com serviço: recebem
// o que mostrar e devolvem o toque para o estado da tela.

/// O que a foto ou a fala trouxe, do jeito que chegou: é o recibo acima
/// dos campos. Os campos podem ser corrigidos depois; o recibo continua
/// mostrando o que foi lido.
@immutable
class _Leitura {
  const _Leitura({
    required this.origem,
    this.valor,
    this.fornecedor,
    this.data,
  });

  final OrigemLancamento origem;
  final double? valor;
  final String? fornecedor;
  final DateTime? data;

  bool get daNota => origem == OrigemLancamento.ocr;
}

/// "Hoje, 19/10/2026": o dia relativo vem primeiro, que é como se fala.
String _rotuloDia(DateTime data) {
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final dia = DateTime(data.year, data.month, data.day);
  final diferenca = hoje.difference(dia).inDays;
  final texto = Formatters.data(data);
  if (diferenca == 0) return 'Hoje, $texto';
  if (diferenca == 1) return 'Ontem, $texto';
  return texto;
}

/// Título da tela com o nome da obra embaixo: o mestre confere em que obra
/// está lançando antes de salvar.
class _Titulo extends StatelessWidget {
  const _Titulo({required this.obra});

  final Stream<ObraModel?> obra;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return StreamBuilder<ObraModel?>(
      stream: obra,
      builder: (context, obra) {
        final nome = obra.data?.nome;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Lançar gasto', maxLines: 1),
            if (nome != null)
              Text(
                nome,
                style: Tipografia.apoio.copyWith(color: c.grafite2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        );
      },
    );
  }
}

/// A folha que sobe ao tocar em "Foto da nota": câmera ou galeria, em
/// linhas de 72 dp, e o "Cancelar" (o equivalente de arrastar para baixo).
class _EscolhaDaFoto extends StatelessWidget {
  const _EscolhaDaFoto();

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Espaco.e16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaco.margem,
                0,
                Espaco.margem,
                Espaco.e8,
              ),
              child: Text(
                'Foto da nota',
                style: Tipografia.titulo.copyWith(color: c.grafite),
              ),
            ),
            LinhaLista(
              titulo: 'Tirar foto da nota',
              apoio: 'Abre a câmera',
              icone: Icons.photo_camera_outlined,
              seta: false,
              divisoria: true,
              vibrar: true,
              aoTocar: () => Navigator.pop(context, ImageSource.camera),
            ),
            LinhaLista(
              titulo: 'Escolher da galeria',
              apoio: 'Uma foto que já está no celular',
              icone: Icons.photo_library_outlined,
              seta: false,
              vibrar: true,
              aoTocar: () => Navigator.pop(context, ImageSource.gallery),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaco.margem,
                Espaco.e8,
                Espaco.margem,
                0,
              ),
              child: BotaoContorno(
                rotulo: 'Cancelar',
                expandir: true,
                aoTocar: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O texto que o OCR leu, na letra de código (é um cupom), para copiar e
/// colar num campo que saiu errado.
class _TextoLido extends StatelessWidget {
  const _TextoLido({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Padding(
      padding: EdgeInsets.only(
        left: Espaco.margem,
        right: Espaco.margem,
        bottom: MediaQuery.of(context).viewPadding.bottom + Espaco.e16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Texto lido da nota',
            style: Tipografia.titulo.copyWith(color: c.grafite),
          ),
          const SizedBox(height: Espaco.e4),
          Text(
            'Se algum campo saiu errado, copie daqui e cole no formulário.',
            style: Tipografia.apoio.copyWith(color: c.grafite2),
          ),
          const SizedBox(height: Espaco.e12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: Folha(
              preenchimento: EdgeInsets.zero,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Espaco.e12),
                child: SelectableText(
                  texto,
                  style: Tipografia.codigo.copyWith(color: c.grafite),
                ),
              ),
            ),
          ),
          const SizedBox(height: Espaco.e16),
          BotaoContorno(
            rotulo: 'Fechar',
            expandir: true,
            aoTocar: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

/// Enquanto o OCR lê: a foto com a varredura passando e o que está
/// acontecendo, em letra grande (no lugar do indicador de 18 px).
class _LendoANota extends StatelessWidget {
  const _LendoANota({required this.foto});

  final File? foto;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final foto = this.foto;
    final larguraPx = (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context))
        .round();
    return Folha(
      destaque: true,
      preenchimento: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 220,
            // A etiqueta da varredura diz o mesmo que o texto embaixo: o
            // leitor de tela anuncia só o texto (uma vez, ao aparecer).
            child: ExcludeSemantics(
              child: Varredura(
                child: foto == null
                    ? ColoredBox(color: c.folhaRebaixada)
                    : Image.file(
                        foto,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 220,
                        cacheWidth: larguraPx,
                        excludeFromSemantics: true,
                      ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: c.grafite, width: Traco.fino),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaco.e16,
                Espaco.e12,
                Espaco.e16,
                Espaco.e16,
              ),
              child: Semantics(
                container: true,
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lendo a nota…',
                      style: Tipografia.titulo.copyWith(color: c.grafite),
                    ),
                    const SizedBox(height: Espaco.e4),
                    Text(
                      'O valor, a data e a loja vão para os campos. Leva '
                      'alguns segundos.',
                      style: Tipografia.apoio.copyWith(color: c.grafite2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// O resultado da leitura como um recibo: o valor grande, o quanto
/// confiar nele, fornecedor e data como células de carimbo, os materiais
/// que vão para o estoque e a foto anexada.
class _Recibo extends StatelessWidget {
  const _Recibo({
    required this.leitura,
    required this.aviso,
    required this.itens,
    required this.foto,
    required this.aoRemoverItem,
    required this.aoRemoverFoto,
    required this.aoVerTextoLido,
  });

  final _Leitura leitura;
  final String? aviso;
  final List<ItemMaterialModel> itens;
  final File? foto;
  final ValueChanged<ItemMaterialModel> aoRemoverItem;
  final VoidCallback aoRemoverFoto;
  final VoidCallback? aoVerTextoLido;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final daNota = leitura.daNota;
    final valor = leitura.valor;
    final data = leitura.data;
    final foto = this.foto;
    final aoVerTextoLido = this.aoVerTextoLido;
    final aviso = this.aviso;
    final separador = BoxDecoration(
      border: Border(top: BorderSide(color: c.traco, width: Traco.fino)),
    );

    return Folha(
      destaque: true,
      preenchimento: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Espaco.e16,
              Espaco.e12,
              Espaco.e16,
              Espaco.e16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      daNota ? Icons.document_scanner_outlined : Icons.mic_none,
                      size: 20,
                      color: c.grafite2,
                    ),
                    const SizedBox(width: Espaco.e8),
                    Expanded(
                      child: Rotulo(
                        daNota ? 'Lido da nota' : 'Entendido da fala',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Espaco.e8),
                if (valor != null)
                  ValorHeroi(valor: valor, contarAoAparecer: true)
                else
                  _Faltou(
                    titulo: daNota ? 'Valor não lido' : 'Valor não entendido',
                    apoio: 'Digite o valor no campo abaixo.',
                  ),
                if (aviso != null) ...[
                  const SizedBox(height: Espaco.e12),
                  AvisoIa(mensagem: aviso),
                ],
              ],
            ),
          ),
          DecoratedBox(
            decoration: separador,
            child: _CelulasDoRecibo(
              fornecedor: leitura.fornecedor,
              data: data,
              faltouFornecedor: daNota ? 'Não lido' : 'Não falado',
              faltouData: daNota ? 'Não lida' : 'Não falada',
            ),
          ),
          if (itens.isNotEmpty)
            DecoratedBox(
              decoration: separador,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaco.e16,
                  Espaco.e12,
                  Espaco.e12,
                  Espaco.e12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Rotulo('Materiais para o estoque'),
                    const SizedBox(height: Espaco.e4),
                    Text(
                      'Entram no estoque quando o lançamento for aprovado. '
                      'Se algum não é desta compra, tire.',
                      style: Tipografia.apoio.copyWith(color: c.grafite2),
                    ),
                    for (final item in itens)
                      Padding(
                        padding: const EdgeInsets.only(top: Espaco.e8),
                        child: _LinhaItem(
                          item: item,
                          aoRemover: () => aoRemoverItem(item),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (foto != null)
            DecoratedBox(
              decoration: separador,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaco.e16,
                  Espaco.e12,
                  Espaco.e12,
                  Espaco.e12,
                ),
                child: _LinhaFoto(foto: foto, aoRemover: aoRemoverFoto),
              ),
            ),
          if (aoVerTextoLido != null)
            DecoratedBox(
              decoration: separador,
              child: Padding(
                padding: const EdgeInsets.all(Espaco.e12),
                child: BotaoContorno(
                  rotulo: 'Ver o texto lido da nota',
                  icone: Icons.subject,
                  expandir: true,
                  aoTocar: aoVerTextoLido,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A foto que não foi lida: a mesma mensagem de sempre, mas dita como
/// erro (traço e ícone no vermelho de revisão), fora do recibo.
class _FalhaDaLeitura extends StatelessWidget {
  const _FalhaDaLeitura({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          Espaco.e12,
          Espaco.e12,
          Espaco.e16,
          Espaco.e12,
        ),
        decoration: BoxDecoration(
          color: c.folha,
          borderRadius: Raio.cantoPequeno,
          border: Border.all(color: c.revisao, width: Traco.forte),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.error_outline, size: 22, color: c.revisao),
            ),
            const SizedBox(width: Espaco.e12),
            Expanded(
              child: Text(
                mensagem,
                style:
                    Tipografia.corpo.copyWith(color: c.grafite, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O valor que a leitura não trouxe: dito com texto, não só com cor.
class _Faltou extends StatelessWidget {
  const _Faltou({required this.titulo, required this.apoio});

  final String titulo;
  final String apoio;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Tipografia.titulo.copyWith(color: c.revisao)),
        const SizedBox(height: 2),
        Text(apoio, style: Tipografia.apoio.copyWith(color: c.grafite2)),
      ],
    );
  }
}

/// Fornecedor e data do recibo, como células do [Carimbo]: lado a lado
/// (3:2, ou meio a meio) enquanto cada texto couber inteiro na célula,
/// sem palavra quebrada no meio e sem passar das 2 linhas da célula;
/// senão, uma embaixo da outra. Com a fonte grande em 360 dp, a data em
/// 3:2 quebrava no meio ("19/10/20" e "26").
class _CelulasDoRecibo extends StatelessWidget {
  const _CelulasDoRecibo({
    required this.fornecedor,
    required this.data,
    required this.faltouFornecedor,
    required this.faltouData,
  });

  final String? fornecedor;
  final DateTime? data;
  final String faltouFornecedor;
  final String faltouData;

  /// Preenchimento lateral da [CelulaCarimbo] (12 de cada lado).
  static const double _lados = Espaco.e12 * 2;

  /// Linhas do valor na [CelulaCarimbo].
  static const int _linhasDoValor = 2;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final data = this.data;
    final textoData = data == null ? null : _rotuloDia(data);
    final escala = MediaQuery.textScalerOf(context);
    final direcao = Directionality.of(context);

    /// O texto cabe na célula de [largura]: nenhuma palavra mais larga que
    /// ela e, o valor, dentro das linhas da célula.
    bool cabe(String? valor, String faltou, double largura) {
      final util = largura - _lados;
      final estilo = valor == null ? Tipografia.apoio : Tipografia.subtitulo;
      TextPainter medir(String texto, int? linhas) => TextPainter(
            text: TextSpan(text: texto, style: estilo),
            textDirection: direcao,
            textScaler: escala,
            maxLines: linhas,
          )..layout(maxWidth: util);
      for (final palavra in (valor ?? faltou).split(RegExp(r'\s+'))) {
        final pintor = medir(palavra, 1);
        final largo = pintor.didExceedMaxLines || pintor.width > util;
        pintor.dispose();
        if (largo) return false;
      }
      if (valor == null) return true;
      final pintor = medir(valor, _linhasDoValor);
      final passou = pintor.didExceedMaxLines;
      pintor.dispose();
      return !passou;
    }

    Widget celula(String rotulo, String? valor, String faltou) => CelulaCarimbo(
          rotulo: rotulo,
          valor: valor ?? '',
          conteudo: valor == null
              ? Text(
                  faltou,
                  style: Tipografia.apoio.copyWith(color: c.grafite2),
                )
              : null,
        );

    return LayoutBuilder(
      builder: (context, limites) {
        final util = limites.maxWidth - Traco.fino;
        int? flexFornecedor;
        for (final (f, d) in [(3, 2), (1, 1)]) {
          if (cabe(fornecedor, faltouFornecedor, util * f / (f + d)) &&
              cabe(textoData, faltouData, util * d / (f + d))) {
            flexFornecedor = f;
            break;
          }
        }
        final fornecedorCel =
            celula('Fornecedor', fornecedor, faltouFornecedor);
        final dataCel = celula('Data', textoData, faltouData);
        if (flexFornecedor == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              fornecedorCel,
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: c.traco, width: Traco.fino),
                  ),
                ),
                child: dataCel,
              ),
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: flexFornecedor, child: fornecedorCel),
              Container(width: Traco.fino, color: c.traco),
              Expanded(flex: flexFornecedor == 3 ? 2 : 1, child: dataCel),
            ],
          ),
        );
      },
    );
  }
}

/// Um material que vai para o estoque, com o botão de tirar (o "✕" do
/// chip virou um botão de 64 dp, com rótulo para o leitor de tela).
class _LinhaItem extends StatelessWidget {
  const _LinhaItem({required this.item, required this.aoRemover});

  final ItemMaterialModel item;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Row(
      children: [
        Icon(Icons.inventory_2_outlined, size: 24, color: c.grafite),
        const SizedBox(width: Espaco.e12),
        Expanded(
          child: Text(
            item.resumo,
            style: Tipografia.corpoForte.copyWith(color: c.grafite),
          ),
        ),
        const SizedBox(width: Espaco.e8),
        BotaoIcone(
          icone: Icons.close,
          rotulo: 'Tirar ${item.resumo} do estoque',
          aoTocar: aoRemover,
        ),
      ],
    );
  }
}

/// A foto da nota que vai junto com o lançamento, com o botão de tirar
/// (o "Desfazer" vem no aviso).
class _LinhaFoto extends StatelessWidget {
  const _LinhaFoto({required this.foto, required this.aoRemover});

  final File foto;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    const lado = 64.0;
    final ladoPx = (lado * MediaQuery.devicePixelRatioOf(context)).round();
    return Row(
      children: [
        Container(
          width: lado,
          height: lado,
          decoration: BoxDecoration(
            color: c.folhaRebaixada,
            border: Border.all(color: c.traco, width: Traco.fino),
          ),
          child: Image.file(
            foto,
            fit: BoxFit.cover,
            cacheWidth: ladoPx,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(width: Espaco.e12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Foto da nota',
                style: Tipografia.corpoForte.copyWith(color: c.grafite),
              ),
              Text(
                'Vai junto com o lançamento.',
                style: Tipografia.apoio.copyWith(color: c.grafite2),
              ),
            ],
          ),
        ),
        const SizedBox(width: Espaco.e8),
        // O mesmo botão de 64 dp de tirar um material: o "Remover" com
        // texto espremia "Vai junto com o lançamento." até quebrar a
        // palavra no meio em 360 dp com a fonte grande.
        BotaoIcone(
          icone: Icons.close,
          rotulo: 'Tirar a foto da nota do lançamento',
          aoTocar: aoRemover,
        ),
      ],
    );
  }
}

/// A data do gasto num campo de 64 dp que abre o calendário. Pressionado
/// ou com foco, ganha a borda grafite de 2 dp do campo em edição.
class _CampoData extends StatelessWidget {
  const _CampoData({required this.data, required this.aoTocar});

  final DateTime data;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final texto = _rotuloDia(data);
    return AreaPressionavel(
      aoTocar: aoTocar,
      escala: 1,
      vibrar: true,
      rotuloSemantico: 'Data do gasto: $texto',
      dicaSemantica: 'Abre o calendário para trocar a data',
      construtor: (context, e) => InputDecorator(
        isFocused: e.focado || e.pressionado,
        decoration: const InputDecoration(
          labelText: 'Data do gasto',
          suffixIcon: Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          texto,
          style: Tipografia.corpo.copyWith(color: c.grafite),
        ),
      ),
    );
  }
}
