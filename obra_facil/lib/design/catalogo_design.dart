// Catálogo do design system: todos os componentes e estados numa tela só.
//
// Não está no router; serve para revisão e para o TCC. Abra com
// `Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogoDesign()))`.

import 'package:flutter/material.dart';

import '../utils/formatters.dart';
import 'design.dart';

/// Tela de catálogo. [brilho] força claro ou escuro; nulo segue o sistema
/// (o botão da barra alterna).
class CatalogoDesign extends StatefulWidget {
  const CatalogoDesign({super.key, this.brilho});

  final Brightness? brilho;

  @override
  State<CatalogoDesign> createState() => _CatalogoDesignState();
}

class _CatalogoDesignState extends State<CatalogoDesign> {
  late Brightness? _brilho = widget.brilho;
  double _gasto = 112380;
  String _categoria = 'material';
  String _pagamento = 'pix';
  String _unidade = 'un';
  Set<String> _fases = {'Alvenaria'};
  String _periodo = 'semana';
  bool _avisar = true;
  bool _resumo = false;
  double _avanco = 0.38;
  final _campoValor = TextEditingController(text: '0,00');

  @override
  void dispose() {
    _campoValor.dispose();
    super.dispose();
  }

  void _alternarBrilho(Brightness atual) => setState(() {
        _brilho = atual == Brightness.dark ? Brightness.light : Brightness.dark;
      });

  @override
  Widget build(BuildContext context) {
    return TemaPrancheta(
      brilho: _brilho,
      child: Builder(builder: _tela),
    );
  }

  Widget _tela(BuildContext context) {
    final c = context.cores;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Design system Prancheta'),
        actions: [
          IconButton(
            tooltip: c.ehEscuro ? 'Tema claro' : 'Tema escuro',
            onPressed: () => _alternarBrilho(c.brilho),
            icon: Icon(
              c.ehEscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: Espaco.e8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Espaco.e48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // O exemplo ocupa a largura toda, como a tela de verdade.
            _secao(
              'Exemplo · central da obra',
              _exemploCentral(context),
              sangrar: true,
            ),
            _secao('Cores', _cores(context)),
            _secao('Tipografia', _tipografia(context)),
            _secao('Espaço, raio e traço', _espaco(context)),
            _secao('Carimbo e folha', _carimboEFolha(context)),
            _secao('Valor e régua de cota', _valorERegua(context)),
            _secao('Notas, hachura e status', _notasEStatus(context)),
            _secao('Botões', _botoes(context)),
            _secao('Linhas de lista', _linhas(context)),
            _secao('Seletor grande', _seletores(context)),
            _secao('Leitura e carregamento', _leitura(context)),
            _secao('Componentes do Material', _material(context)),
          ],
        ),
      ),
      bottomNavigationBar: BarraDeAcao(
        principal: BotaoPrincipal(
          rotulo: 'Revisar os 3 gastos',
          aoTocar: () {},
        ),
        secundaria: BotaoIcone(
          icone: Icons.add,
          rotulo: 'Lançar gasto',
          estilo: EstiloBotaoIcone.marca,
          aoTocar: () {},
        ),
      ),
    );
  }

  /// Seção do catálogo: a linha de cota com o nome e o conteúdo. Com
  /// [sangrar], o conteúdo vai de borda a borda.
  Widget _secao(String titulo, Widget conteudo, {bool sangrar = false}) {
    const margem = EdgeInsets.symmetric(horizontal: Espaco.margem);
    return Padding(
      padding: const EdgeInsets.only(top: Espaco.e24, bottom: Espaco.e8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: margem,
            child: Semantics(header: true, child: LinhaCota(legenda: titulo)),
          ),
          const SizedBox(height: Espaco.e16),
          if (sangrar) conteudo else Padding(padding: margem, child: conteudo),
        ],
      ),
    );
  }

  Widget _legenda(BuildContext context, String texto) => Padding(
        padding: const EdgeInsets.only(top: Espaco.e16, bottom: Espaco.e8),
        child: Rotulo(texto, maxLinhas: 2),
      );

  // ---------------------------------------------------------------- exemplo

  Widget _exemploCentral(BuildContext context) {
    final c = context.cores;
    final pasta = c.ehEscuro ? 'escuro' : 'claro';
    const margem = EdgeInsets.symmetric(horizontal: Espaco.margem);
    return DecoratedBox(
      // A "tela" do exemplo, entre dois traços grafite.
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: c.grafite, width: Traco.fino),
        ),
      ),
      child: ColoredBox(
        color: c.papel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                Espaco.margem,
                Espaco.e16,
                Espaco.margem,
                0,
              ),
              child: Carimbo(
                linhas: [
                  [
                    CelulaCarimbo(
                      rotulo: 'Obra',
                      valor: 'Sobrado Vila Izabel',
                      destaque: true,
                    ),
                  ],
                  [
                    CelulaCarimbo(rotulo: 'Fase', valor: 'Alvenaria'),
                    CelulaCarimbo(rotulo: 'Semana', valor: '14 de 32'),
                  ],
                ],
              ),
            ),
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.asset(
                    'assets/3d/reserva/$pasta/estado_04.webp',
                    fit: BoxFit.cover,
                    semanticLabel: 'Maquete da obra: alvenaria levantada, '
                        'o que falta em tracejado',
                    errorBuilder: (context, erro, pilha) => CaixaHachurada(
                      cor: c.grade,
                      contorno: false,
                    ),
                  ),
                ),
                const Positioned(
                  left: Espaco.margem,
                  bottom: Espaco.e8,
                  child: _FundoPapel(
                    child: LegendaTracejada('ainda não construído'),
                  ),
                ),
              ],
            ),
            Padding(
              padding: margem,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ValorHeroi(valor: 112380, rotulo: 'Gasto até agora'),
                  const SizedBox(height: Espaco.e4),
                  Text(
                    'de ${Formatters.moeda(260000)} · 43% do orçamento',
                    style: Tipografia.apoio.copyWith(color: c.grafite2),
                  ),
                  const SizedBox(height: Espaco.e12),
                  const ReguaCota(
                    valor: 0.43,
                    marcador: 0.38,
                    legenda: 'avanço 38%',
                    rotuloSemantico: 'Orçamento usado',
                  ),
                  const SizedBox(height: Espaco.e12),
                  const NotaRevisao('5 pontos acima do avanço'),
                ],
              ),
            ),
            const SizedBox(height: Espaco.e16),
            Padding(
              padding: margem,
              child: Folha(
                destaque: true,
                preenchimento: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CabecalhoFila(
                      titulo: '3 gastos para aprovar',
                      valor: Formatters.moeda(4912.40),
                    ),
                    LinhaLista(
                      titulo: 'Bloco cerâmico 9 furos',
                      apoio: '2.000 un · Casa do Construtor',
                      valor: Formatters.moeda(2380),
                      margemHorizontal: Espaco.e12,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Espaco.e12,
                        0,
                        Espaco.e12,
                        Espaco.e12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: BotaoPrincipal(
                              rotulo: 'Aprovar',
                              icone: Icons.check,
                              aoTocar: () {},
                            ),
                          ),
                          const SizedBox(width: Espaco.entreAlvos),
                          Expanded(
                            child: BotaoContorno(
                              rotulo: 'Recusar',
                              icone: Icons.close,
                              aoTocar: () {},
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Espaco.e16),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ cores

  Widget _cores(BuildContext context) {
    final c = context.cores;
    final tokens = <(String, Color, String)>[
      ('papel', c.papel, 'fundo das telas'),
      ('folha', c.folha, 'superfícies'),
      ('folhaRebaixada', c.folhaRebaixada, 'recuos, trilho'),
      ('grafite', c.grafite, 'texto principal'),
      ('grafite2', c.grafite2, 'texto secundário'),
      ('traco', c.traco, 'bordas e ícones'),
      ('grade', c.grade, 'divisórias'),
      ('marca', c.marca, 'destaque'),
      ('sobreMarca', c.sobreMarca, 'texto no laranja'),
      ('marcaTexto', c.marcaTexto, 'laranja como texto'),
      ('revisao', c.revisao, 'erro, recusa'),
      ('ok', c.ok, 'aprovado'),
      ('aviso', c.aviso, 'atenção'),
      ('sobreGrafite', c.sobreGrafite, 'texto no grafite'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Como a legenda de materiais de uma prancha: uma tabela, não uma
        // grade de cartões.
        Folha(
          preenchimento: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tokens.length; i++)
                _Amostra(
                  nome: tokens[i].$1,
                  cor: tokens[i].$2,
                  uso: tokens[i].$3,
                  primeira: i == 0,
                ),
            ],
          ),
        ),
        const SizedBox(height: Espaco.e16),
        Folha(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Rotulo('Contraste medido (WCAG 2.2)'),
              const SizedBox(height: Espaco.e8),
              for (final (rotulo, frente, fundo) in [
                ('grafite no papel', c.grafite, c.papel),
                ('grafite na folha', c.grafite, c.folha),
                ('grafite2 na folha', c.grafite2, c.folha),
                ('traço na folha', c.traco, c.folha),
                ('preto na marca', c.sobreMarca, c.marca),
                ('marcaTexto na folha', c.marcaTexto, c.folha),
                ('revisão na folha', c.revisao, c.folha),
                ('ok na folha', c.ok, c.folha),
                ('preto no aviso', c.sobreAviso, c.aviso),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          rotulo,
                          style: Tipografia.apoio.copyWith(color: c.grafite2),
                        ),
                      ),
                      Text(
                        '${CoresObra.contraste(frente, fundo).toStringAsFixed(1).replaceAll('.', ',')}:1',
                        style: Tipografia.corpoForte.copyWith(color: c.grafite),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- tipografia

  Widget _tipografia(BuildContext context) {
    final c = context.cores;
    final papeis = <(String, TextStyle, String)>[
      ('Valor-herói · Archivo 40/800', Tipografia.valorHeroi, 'R\$ 112.380,00'),
      (
        'Título de tela · Archivo 30/800',
        Tipografia.tituloTela,
        'Sobrado Vila Izabel'
      ),
      ('Título · Archivo 22/700', Tipografia.titulo, 'Gastos da semana'),
      (
        'Subtítulo · Archivo 18/700',
        Tipografia.subtitulo,
        '3 gastos para aprovar'
      ),
      (
        'Corpo · Atkinson 17/400',
        Tipografia.corpo,
        'A nota foi lida e os itens já estão preenchidos. Confira o valor '
            'antes de salvar.',
      ),
      (
        'Corpo forte · Atkinson 17/700',
        Tipografia.corpoForte,
        'Bloco cerâmico 9 furos'
      ),
      (
        'Apoio · Atkinson 15/400',
        Tipografia.apoio,
        '2.000 un · Casa do Construtor'
      ),
      ('Rótulo · Archivo 13/700', Tipografia.rotulo, 'VALOR DA NOTA'),
      (
        'Código · Plex Mono 15/500',
        Tipografia.codigo,
        '4126 0512 3456 7800 0190 5500 1000 0012 3410 0012 3456',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (nome, estilo, amostra) in papeis) ...[
          Rotulo(nome),
          const SizedBox(height: Espaco.e4),
          Text(amostra, style: estilo.copyWith(color: c.grafite)),
          const SizedBox(height: Espaco.e16),
        ],
        Folha(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Rotulo('Sem confusão sob reflexo'),
              const SizedBox(height: Espaco.e4),
              Text(
                '0O 1lI 5S 8B',
                style: Tipografia.titulo.copyWith(
                  fontFamily: Tipografia.familiaTexto,
                  color: c.grafite,
                ),
              ),
              const SizedBox(height: Espaco.e12),
              const Rotulo('Algarismos tabulares'),
              const SizedBox(height: Espaco.e4),
              for (final v in [1111.11, 8888.88, 10450.0])
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    Formatters.moeda(v),
                    style: Tipografia.corpoForte.copyWith(color: c.grafite),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- espaço

  Widget _espaco(BuildContext context) {
    final c = context.cores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in [
          Espaco.e4,
          Espaco.e8,
          Espaco.e12,
          Espaco.e16,
          Espaco.e24,
          Espaco.e32,
          Espaco.e48,
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: Espaco.e4),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    e.toStringAsFixed(0),
                    style: Tipografia.apoio.copyWith(color: c.grafite2),
                  ),
                ),
                Container(width: e * 3, height: 12, color: c.grafite),
              ],
            ),
          ),
        _legenda(context, 'Raio: 0 · 2 · 4 · 8 (topo da folha) · pílula'),
        Wrap(
          spacing: Espaco.e12,
          runSpacing: Espaco.e12,
          children: [
            for (final r in [
              BorderRadius.zero,
              Raio.cantoPequeno,
              Raio.cantoPadrao,
              Raio.topoFolha,
              BorderRadius.circular(Raio.pilula),
            ])
              Container(
                width: 56,
                height: 40,
                decoration: BoxDecoration(
                  color: c.folha,
                  borderRadius: r,
                  border: Border.all(color: c.grafite, width: Traco.fino),
                ),
              ),
          ],
        ),
        _legenda(context, 'Traço: fino 1,5 · forte 2'),
        Container(height: Traco.fino, color: c.grafite),
        const SizedBox(height: Espaco.e12),
        Container(height: Traco.forte, color: c.grafite),
      ],
    );
  }

  // -------------------------------------------------------- carimbo e folha

  Widget _carimboEFolha(BuildContext context) {
    final c = context.cores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Carimbo(
          linhas: [
            [
              CelulaCarimbo(rotulo: 'Lançamento', valor: 'Nota 000.123'),
              CelulaCarimbo(rotulo: 'Data', valor: '14/10/2026'),
            ],
            [
              CelulaCarimbo(
                  rotulo: 'Fornecedor', valor: 'Casa do Construtor', flex: 2),
              CelulaCarimbo(rotulo: 'Itens', valor: '4'),
            ],
          ],
        ),
        const SizedBox(height: Espaco.e16),
        Folha(
          child: Text(
            'Folha: superfície com borda de 1,5 dp na cor do traço e raio 4. '
            'Sem sombra.',
            style: Tipografia.corpo.copyWith(color: c.grafite),
          ),
        ),
        const SizedBox(height: Espaco.e12),
        Folha(
          destaque: true,
          child: Text(
            'Folha destaque: borda grafite de 2 dp, para o que pede atenção.',
            style: Tipografia.corpo.copyWith(color: c.grafite),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------- valor e régua

  Widget _valorERegua(BuildContext context) {
    final c = context.cores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Folha(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValorHeroi(valor: _gasto, rotulo: 'Gasto até agora'),
              const SizedBox(height: Espaco.e12),
              Wrap(
                spacing: Espaco.e12,
                runSpacing: Espaco.e12,
                children: [
                  BotaoContorno(
                    rotulo: 'Somar R\$ 2.380',
                    icone: Icons.add,
                    aoTocar: () => setState(() => _gasto += 2380),
                  ),
                  BotaoContorno(
                    rotulo: 'Voltar',
                    aoTocar: () => setState(() => _gasto = 112380),
                  ),
                ],
              ),
            ],
          ),
        ),
        _legenda(context, 'Régua sem marcador · 64%'),
        const ReguaCota(valor: 0.64, rotuloSemantico: 'Avanço'),
        _legenda(context, 'Com marcador e legenda'),
        ReguaCota(
          valor: 0.43,
          marcador: _avanco,
          legenda: 'avanço ${(_avanco * 100).round()}%',
          rotuloSemantico: 'Orçamento usado',
        ),
        _legenda(context, 'Marcador perto do início'),
        const ReguaCota(valor: 0.12, marcador: 0.06, legenda: 'avanço 6%'),
        _legenda(context, 'Acima de 100% (régua cheia)'),
        const ReguaCota(valor: 1.12, marcador: 0.9, legenda: 'avanço 90%'),
        _legenda(context, 'Linha de cota'),
        const LinhaCota(),
        const SizedBox(height: Espaco.e8),
        const LinhaCota(legenda: 'Semana 14'),
        const SizedBox(height: Espaco.e8),
        Text(
          'Arraste o slider em "Componentes do Material" para mover o '
          'marcador.',
          style: Tipografia.apoio.copyWith(color: c.grafite2),
        ),
      ],
    );
  }

  // ------------------------------------------------ notas, hachura, status

  Widget _notasEStatus(BuildContext context) {
    final c = context.cores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: Espaco.e8,
          runSpacing: Espaco.e8,
          children: [
            NotaRevisao('5 pontos acima do avanço'),
            NotaRevisao('R\$ 1.200 acima do previsto',
                icone: Icons.trending_up),
            NotaRevisao('Lido pela câmera', tipo: TipoNota.marca),
          ],
        ),
        _legenda(context, 'Selo de status'),
        const Wrap(
          spacing: Espaco.e8,
          runSpacing: Espaco.e8,
          children: [
            SeloStatus(StatusSelo.pendente),
            SeloStatus(StatusSelo.aprovado),
            SeloStatus(StatusSelo.recusado),
            SeloStatus(StatusSelo.aviso),
          ],
        ),
        _legenda(context, 'Hachura: o que está pendente ou falta'),
        SizedBox(
          height: 96,
          width: double.infinity,
          child: CaixaHachurada(
            cor: c.traco,
            child: Center(
              child: _FundoPapel(
                child: Text(
                  'Reboco · ainda não começou',
                  style: Tipografia.corpoForte.copyWith(color: c.grafite),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- botões

  Widget _botoes(BuildContext context) {
    final c = context.cores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BotaoPrincipal(
          rotulo: 'Salvar gasto',
          icone: Icons.check,
          grande: true,
          aoTocar: () {},
        ),
        const SizedBox(height: Espaco.entreAlvos),
        BotaoPrincipal(rotulo: 'Revisar os 3 gastos', aoTocar: () {}),
        const SizedBox(height: Espaco.entreAlvos),
        BotaoMarca(
          rotulo: 'Lançar gasto',
          icone: Icons.add,
          aoTocar: () {},
        ),
        const SizedBox(height: Espaco.entreAlvos),
        BotaoContorno(
          rotulo: 'Ler a nota pela câmera',
          icone: Icons.photo_camera_outlined,
          aoTocar: () {},
        ),
        _legenda(context, 'Carregando e desabilitado'),
        BotaoPrincipal(
          rotulo: 'Salvando',
          carregando: true,
          aoTocar: () {},
        ),
        const SizedBox(height: Espaco.entreAlvos),
        const BotaoPrincipal(rotulo: 'Salvar gasto', aoTocar: null),
        const SizedBox(height: Espaco.entreAlvos),
        const BotaoContorno(rotulo: 'Sem itens para revisar', aoTocar: null),
        const SizedBox(height: Espaco.entreAlvos),
        BotaoMarca(
          rotulo: 'Lendo a nota',
          icone: Icons.add,
          carregando: true,
          aoTocar: () {},
        ),
        const SizedBox(height: Espaco.entreAlvos),
        const BotaoMarca(rotulo: 'Lançar gasto', aoTocar: null),
        _legenda(context, 'Botão de ícone · 64 dp'),
        Wrap(
          spacing: Espaco.entreAlvos,
          runSpacing: Espaco.entreAlvos,
          children: [
            BotaoIcone(
              icone: Icons.mic_none,
              rotulo: 'Falar o gasto',
              aoTocar: () {},
            ),
            BotaoIcone(
              icone: Icons.add,
              rotulo: 'Lançar gasto',
              estilo: EstiloBotaoIcone.marca,
              aoTocar: () {},
            ),
            BotaoIcone(
              icone: Icons.photo_camera_outlined,
              rotulo: 'Foto do canteiro',
              estilo: EstiloBotaoIcone.principal,
              aoTocar: () {},
            ),
            BotaoIcone(
              icone: Icons.send_outlined,
              rotulo: 'Enviar',
              estilo: EstiloBotaoIcone.principal,
              carregando: true,
              aoTocar: () {},
            ),
            const BotaoIcone(
              icone: Icons.delete_outline,
              rotulo: 'Excluir',
              aoTocar: null,
            ),
          ],
        ),
        const SizedBox(height: Espaco.e12),
        Text(
          'Pressionado: o botão encolhe e o fundo muda (cor sólida). '
          'Desabilitado: sem fundo, contorno tracejado. Foco de teclado: '
          'contorno laranja de 3 dp.',
          style: Tipografia.apoio.copyWith(color: c.grafite2),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- linhas

  Widget _linhas(BuildContext context) {
    return Folha(
      preenchimento: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinhaLista(
            icone: Icons.receipt_long_outlined,
            titulo: 'Cimento CP II-E-32',
            apoio: '40 sacos · Depósito Silva',
            valor: Formatters.moeda(1290),
            divisoria: true,
            margemHorizontal: Espaco.e12,
            aoTocar: () {},
          ),
          LinhaLista(
            inicio: const CaixaHachurada(largura: 16, altura: 32),
            titulo: 'Areia média',
            apoio: '6 m³ · Areial São Jorge',
            valor: Formatters.moeda(840),
            divisoria: true,
            margemHorizontal: Espaco.e12,
            fim: const SeloStatus(StatusSelo.pendente),
          ),
          LinhaLista(
            icone: Icons.engineering_outlined,
            titulo: 'Diária de pedreiro com nome comprido para quebrar a linha',
            apoio: 'Semana 14',
            valor: Formatters.moeda(1800),
            divisoria: true,
            margemHorizontal: Espaco.e12,
            aoTocar: () {},
          ),
          const LinhaLista(
            icone: Icons.check,
            titulo: 'Fundação',
            apoio: 'Concluída em 02/09',
            fim: SeloStatus(StatusSelo.aprovado),
            margemHorizontal: Espaco.e12,
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- seletor

  Widget _seletores(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeletorGrande<String>(
          rotulo: 'Categoria do gasto',
          opcoes: const [
            OpcaoSeletor(valor: 'material', rotulo: 'Material'),
            OpcaoSeletor(valor: 'mao', rotulo: 'Mão de obra'),
            OpcaoSeletor(valor: 'equip', rotulo: 'Equipamento'),
            OpcaoSeletor(valor: 'outros', rotulo: 'Outros'),
          ],
          selecionado: _categoria,
          aoMudar: (v) => setState(() => _categoria = v),
        ),
        const SizedBox(height: Espaco.e24),
        SeletorGrande<String>(
          rotulo: 'Pagamento',
          opcoes: const [
            OpcaoSeletor(valor: 'pix', rotulo: 'Pix'),
            OpcaoSeletor(valor: 'dinheiro', rotulo: 'Dinheiro'),
            OpcaoSeletor(valor: 'cartao', rotulo: 'Cartão'),
          ],
          selecionado: _pagamento,
          aoMudar: (v) => setState(() => _pagamento = v),
        ),
        const SizedBox(height: Espaco.e24),
        SeletorGrande<String>(
          rotulo: 'Unidade',
          opcoes: const [
            OpcaoSeletor(valor: 'un', rotulo: 'Unidade'),
            OpcaoSeletor(valor: 'm3', rotulo: 'm³'),
          ],
          selecionado: _unidade,
          aoMudar: (v) => setState(() => _unidade = v),
        ),
        const SizedBox(height: Espaco.e24),
        const SeletorGrande<String>(
          rotulo: 'Desabilitado',
          opcoes: [
            OpcaoSeletor(valor: 'a', rotulo: 'Sim'),
            OpcaoSeletor(valor: 'b', rotulo: 'Não'),
          ],
          selecionado: 'a',
          aoMudar: null,
        ),
      ],
    );
  }

  // ------------------------------------------------- leitura e carregamento

  Widget _leitura(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 240,
          child: Varredura(child: _NotaDeExemplo()),
        ),
        SizedBox(height: Espaco.e16),
        EsqueletoFolha(),
      ],
    );
  }

  // -------------------------------------------------------------- material

  Widget _material(BuildContext context) {
    final c = context.cores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TextField(
          decoration: InputDecoration(
            labelText: 'Descrição',
            hintText: 'Ex.: bloco cerâmico',
          ),
        ),
        const SizedBox(height: Espaco.e16),
        TextField(
          controller: _campoValor,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Valor (R\$)',
            errorText: 'Digite um valor maior que zero',
          ),
        ),
        const SizedBox(height: Espaco.e16),
        const TextField(
          enabled: false,
          decoration: InputDecoration(labelText: 'Fornecedor (bloqueado)'),
        ),
        const SizedBox(height: Espaco.e16),
        // Para ler sem editar: readOnly (o desabilitado apaga o texto).
        TextFormField(
          readOnly: true,
          initialValue: 'Casa do Construtor',
          decoration: const InputDecoration(
            labelText: 'Fornecedor (lido da nota)',
            suffixIcon: Icon(Icons.lock_outline),
          ),
        ),
        _legenda(context, 'Chips'),
        Wrap(
          spacing: Espaco.entreAlvos,
          runSpacing: Espaco.entreAlvos,
          children: [
            for (final f in ['Fundação', 'Estrutura', 'Alvenaria', 'Cobertura'])
              FilterChip(
                label: Text(f),
                selected: _fases.contains(f),
                onSelected: (s) => setState(() {
                  _fases = {..._fases};
                  s ? _fases.add(f) : _fases.remove(f);
                }),
              ),
            const Chip(label: Text('Só leitura')),
          ],
        ),
        const SizedBox(height: Espaco.entreAlvos),
        Wrap(
          spacing: Espaco.entreAlvos,
          runSpacing: Espaco.entreAlvos,
          children: [
            for (final p in ['Hoje', 'Semana', 'Mês'])
              ChoiceChip(
                label: Text(p),
                selected: _periodo == p.toLowerCase(),
                onSelected: (_) => setState(() => _periodo = p.toLowerCase()),
              ),
          ],
        ),
        _legenda(
          context,
          'Botões segmentados · nas telas novas, use o SeletorGrande',
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'hoje', label: Text('Hoje')),
            ButtonSegment(value: 'semana', label: Text('Semana')),
            ButtonSegment(value: 'mês', label: Text('Mês')),
          ],
          selected: {_periodo},
          onSelectionChanged: (s) => setState(() => _periodo = s.first),
        ),
        _legenda(context, 'Interruptor, slider e progresso'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Avisar quando passar do orçamento'),
          value: _avisar,
          onChanged: (v) => setState(() => _avisar = v),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Mandar o resumo da semana ao cliente'),
          value: _resumo,
          onChanged: (v) => setState(() => _resumo = v ?? false),
        ),
        Slider(
          value: _avanco,
          onChanged: (v) => setState(() => _avanco = v),
        ),
        const SizedBox(height: Espaco.e8),
        const LinearProgressIndicator(value: 0.6),
        const SizedBox(height: Espaco.e16),
        const Row(
          children: [
            SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(value: 0.7),
            ),
            SizedBox(width: Espaco.e12),
            Expanded(child: Text('Enviando 7 de 10 fotos')),
          ],
        ),
        _legenda(context, 'Lista do Material'),
        const ListTile(
          leading: Icon(Icons.inventory_2_outlined),
          title: Text('Estoque de cimento'),
          subtitle: Text('Dura mais 6 dias no ritmo atual'),
          trailing: Text('12 sacos'),
        ),
        const Divider(),
        _legenda(context, 'Botões do Material (telas antigas)'),
        FilledButton(onPressed: () {}, child: const Text('FilledButton')),
        const SizedBox(height: Espaco.entreAlvos),
        OutlinedButton(onPressed: () {}, child: const Text('OutlinedButton')),
        const SizedBox(height: Espaco.entreAlvos),
        Row(
          children: [
            TextButton(onPressed: () {}, child: const Text('TextButton')),
            const Spacer(),
            PopupMenuButton<String>(
              tooltip: 'Mais opções',
              onSelected: (_) {},
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(value: 'duplicar', child: Text('Duplicar')),
                PopupMenuItem(value: 'excluir', child: Text('Excluir')),
              ],
            ),
          ],
        ),
        _legenda(context, 'Aviso (com desfazer), diálogo e folha'),
        Wrap(
          spacing: Espaco.entreAlvos,
          runSpacing: Espaco.entreAlvos,
          children: [
            BotaoContorno(
              rotulo: 'Aviso',
              aoTocar: () =>
                  mostrarAviso(context, 'Gasto aprovado.', aoDesfazer: () {}),
            ),
            BotaoContorno(
              rotulo: 'Diálogo',
              aoTocar: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Excluir a foto?'),
                  content: const Text('A foto sai do diário desta semana.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Excluir'),
                    ),
                  ],
                ),
              ),
            ),
            BotaoContorno(
              rotulo: 'Folha',
              aoTocar: () => showModalBottomSheet<void>(
                context: context,
                builder: (context) => Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.margem,
                    0,
                    Espaco.margem,
                    Espaco.e24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Folha que sobe de baixo',
                        style: Tipografia.titulo.copyWith(color: c.grafite),
                      ),
                      const SizedBox(height: Espaco.e16),
                      BotaoPrincipal(
                        rotulo: 'Fechar',
                        expandir: true,
                        aoTocar: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Linha da tabela de cores: amostra, nome, uso e hexadecimal.
class _Amostra extends StatelessWidget {
  const _Amostra({
    required this.nome,
    required this.cor,
    required this.uso,
    required this.primeira,
  });

  final String nome;
  final Color cor;
  final String uso;
  final bool primeira;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final hex = cor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.e12,
        vertical: Espaco.e8,
      ),
      decoration: BoxDecoration(
        border: primeira
            ? null
            : Border(top: BorderSide(color: c.grade, width: Traco.fino)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cor,
              border: Border.all(color: c.traco, width: Traco.fino),
            ),
          ),
          const SizedBox(width: Espaco.e12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: Tipografia.corpoForte.copyWith(color: c.grafite),
                ),
                Text(
                  uso,
                  style: Tipografia.apoio.copyWith(color: c.grafite2),
                ),
              ],
            ),
          ),
          const SizedBox(width: Espaco.e8),
          Text(
            '#${hex.toUpperCase()}',
            style: Tipografia.codigo.copyWith(color: c.grafite2),
          ),
        ],
      ),
    );
  }
}

/// Cabeçalho da fila de aprovação no exemplo: hachura (pendente), título
/// e o total.
class _CabecalhoFila extends StatelessWidget {
  const _CabecalhoFila({required this.titulo, required this.valor});

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final estilo = Tipografia.subtitulo.copyWith(color: c.grafite);
    return MergeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: Alvo.mestre),
        padding: const EdgeInsets.symmetric(
          horizontal: Espaco.e12,
          vertical: Espaco.e12,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.grade, width: Traco.fino)),
        ),
        child: Row(
          children: [
            const CaixaHachurada(largura: 16, altura: 32),
            const SizedBox(width: Espaco.e12),
            // Como na LinhaLista: o total fica com até 45% e encolhe se não
            // couber.
            Expanded(
              child: ParComValor(
                esquerda: Text(titulo, style: estilo),
                direita: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(valor, style: estilo, maxLines: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fundo de papel atrás de uma legenda sobre imagem ou hachura: nada de
/// texto direto sobre fundo movimentado.
class _FundoPapel extends StatelessWidget {
  const _FundoPapel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        color: context.cores.papel,
        child: child,
      );
}

/// Uma "foto" de cupom fiscal desenhada, para a varredura ter o que ler.
/// Fica sempre clara, como uma foto de papel de verdade.
class _NotaDeExemplo extends StatelessWidget {
  const _NotaDeExemplo();

  @override
  Widget build(BuildContext context) {
    const tinta = Color(0xFF2B2B2B);
    final estilo = Tipografia.codigo.copyWith(
      color: tinta,
      fontSize: 12,
      height: 1.5,
    );
    const linhas = [
      'CASA DO CONSTRUTOR LTDA',
      'CUPOM FISCAL ELETRONICO',
      '',
      'BLOCO CER 9F  2000  2.380,00',
      'CIMENTO CPII    40  1.290,00',
      'AREIA MEDIA M3   6    840,00',
      '',
      'TOTAL R\$          4.510,00',
    ];
    // É uma foto: o texto dela não cresce com a fonte do sistema e o
    // leitor de tela ouve a legenda da varredura, não o cupom.
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: Container(
          color: const Color(0xFFE9E4DA),
          alignment: Alignment.center,
          child: Container(
            width: 250,
            margin: const EdgeInsets.symmetric(vertical: Espaco.e12),
            padding: const EdgeInsets.fromLTRB(
              Espaco.e16,
              Espaco.e32,
              Espaco.e12,
              Espaco.e12,
            ),
            color: const Color(0xFFFBFAF6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final linha in linhas)
                  Text(linha, style: estilo, maxLines: 1, softWrap: false),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
