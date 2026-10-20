import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/itens_parser.dart';
import '../../services/ia/ocr_nota_service.dart';
import '../../services/ia/voz_service.dart';
import '../../services/imagem_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/botao_ia.dart';
import '../../widgets/painel_voz.dart';

part 'novo_lancamento_partes.dart';

/// Lançar gasto: a tarefa mais frequente do mestre, de luva e com uma mão.
///
/// A tela fica na prancheta ([TemaPrancheta], claro ou escuro pelo
/// sistema): primeiro as duas capturas grandes (foto da nota e fala), o
/// resultado da leitura como um recibo e, embaixo, o formulário à mão. O
/// "Salvar lançamento" fica fixo no rodapé.
///
/// `?inicio=foto` ou `?inicio=voz` na rota já abre a câmera ou o
/// microfone, como se o botão tivesse sido tocado.
class NovoLancamentoScreen extends StatelessWidget {
  final String obraId;

  const NovoLancamentoScreen({super.key, required this.obraId});

  /// O erro cru do Firebase ("[cloud_firestore/permission-denied] ...")
  /// não diz a quem está lançando o que fazer.
  @visibleForTesting
  static String mensagemAoSalvar(Object erro) {
    if (erro is FirebaseException) {
      switch (erro.code) {
        case 'permission-denied':
          return 'Você não tem permissão para lançar nesta obra. '
              'Fale com o dono da obra.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Sem conexão com o servidor agora. Confira a internet e '
              'tente de novo.';
      }
    }
    if (erro is FileSystemException) {
      return 'Não consegui anexar a foto da nota. Remova a foto ou tire '
          'outra e salve de novo.';
    }
    return 'Não foi possível salvar o lançamento. Tente de novo em '
        'instantes.';
  }

  // O tema fica acima do estado: os diálogos, folhas e avisos que o
  // estado abre com o próprio context saem na prancheta também.
  @override
  Widget build(BuildContext context) =>
      TemaPrancheta(child: _NovoLancamento(obraId: obraId));
}

class _NovoLancamento extends StatefulWidget {
  final String obraId;

  const _NovoLancamento({required this.obraId});

  @override
  State<_NovoLancamento> createState() => _NovoLancamentoScreenState();
}

class _NovoLancamentoScreenState extends State<_NovoLancamento> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _fornecedorCtrl = TextEditingController();

  CategoriaCusto _categoria = CategoriaCusto.material;
  DateTime _data = DateTime.now();
  OrigemLancamento _origem = OrigemLancamento.manual;
  File? _fotoNota;
  String? _cnpjExtraido;
  String? _avisoIa;
  String? _textoOcr;
  List<ItemMaterialModel> _itens = [];
  bool _processando = false;
  bool _salvando = false;

  final _ocr = OcrNotaService();
  final _voz = VozService();

  // Só interface: a foto enquanto o OCR lê (para a varredura), o que a
  // leitura trouxe (o recibo), a obra (o nome no título) e onde rolar
  // quando falta um campo obrigatório.
  File? _fotoEmLeitura;
  _Leitura? _leitura;

  /// A última foto não foi lida: o aviso é o erro dela, não a confiança da
  /// leitura que está no recibo (que continua a da leitura anterior, como
  /// os campos).
  bool _leituraFalhou = false;
  late final Stream<ObraModel?> _obra;
  final _chaveDescricao = GlobalKey();
  final _chaveValor = GlobalKey();

  @override
  void initState() {
    super.initState();
    _obra = context.read<FirestoreService>().obra(widget.obraId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _comecarPelaRota());
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _valorCtrl.dispose();
    _fornecedorCtrl.dispose();
    _ocr.dispose();
    super.dispose();
  }

  /// `?inicio=foto` / `?inicio=voz`: a mesma ação do botão, uma vez só,
  /// depois do primeiro quadro.
  void _comecarPelaRota() {
    if (!mounted || GoRouter.maybeOf(context) == null) return;
    final inicio = GoRouterState.of(context).uri.queryParameters['inicio'];
    if (_processando) return;
    switch (inicio) {
      case 'foto':
        unawaited(_lerNotaFiscal());
      case 'voz':
        unawaited(_lancarPorVoz());
    }
  }

  // ------------------------------------------------------------------ OCR

  Future<void> _lerNotaFiscal() async {
    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => const _EscolhaDaFoto(),
    );
    if (origem == null) return;

    final xfile = await ImagePicker().pickImage(
      source: origem,
      imageQuality: 92,
      maxWidth: 2200,
    );
    if (xfile == null || !mounted) return;

    setState(() {
      _processando = true;
      _avisoIa = null;
      _fotoEmLeitura = File(xfile.path);
      _leituraFalhou = false;
    });

    try {
      final nota = await _ocr.lerNota(xfile.path);
      if (!mounted) return;
      // O texto remontado pela posição na foto põe o nome do produto e o
      // preço da outra coluna na mesma linha, como estão no papel — é
      // dele que os itens e a conferência na tela saem melhor.
      final textoLido = nota.textoReconstruido ?? nota.textoCompleto;
      setState(() {
        _fotoNota = File(xfile.path);
        _origem = OrigemLancamento.ocr;
        _categoria = CategoriaCusto.material;
        if (nota.valorTotal != null) {
          _valorCtrl.text =
              nota.valorTotal!.toStringAsFixed(2).replaceAll('.', ',');
        }
        if (nota.data != null) _data = nota.data!;
        if (nota.fornecedorNome != null) {
          _fornecedorCtrl.text = nota.fornecedorNome!;
          if (_descricaoCtrl.text.isEmpty) {
            _descricaoCtrl.text = 'Compra em ${nota.fornecedorNome}';
          }
        }
        _cnpjExtraido = nota.cnpj;
        _textoOcr = textoLido.trim().isEmpty ? null : textoLido;
        _itens = ItensParser.deNotaOcr(textoLido);
        _avisoIa = OcrNotaService.avisoDaLeitura(nota);
        _leitura = _Leitura(
          origem: OrigemLancamento.ocr,
          valor: nota.valorTotal,
          fornecedor: nota.fornecedorNome,
          data: nota.data,
        );
      });
      unawaited(nota.encontrouAlgo ? Tato.confirmar() : Tato.erro());
    } catch (e) {
      if (!mounted) return;
      // O erro técnico ("PlatformException(...)") não diz a quem está no
      // canteiro o que fazer; a mensagem diz.
      setState(() {
        _avisoIa = OcrNotaService.mensagemDeErro(e);
        _leituraFalhou = true;
      });
      unawaited(Tato.erro());
    } finally {
      if (mounted) {
        setState(() {
          _processando = false;
          _fotoEmLeitura = null;
        });
      }
    }
  }

  // ------------------------------------------------------------------ Voz

  Future<void> _lancarPorVoz() async {
    final interpretado = await mostrarPainelVoz(context, _voz);
    if (interpretado == null || !mounted) return;

    setState(() {
      _origem = OrigemLancamento.voz;
      _itens = interpretado.itens;
      _descricaoCtrl.text = interpretado.descricao;
      if (interpretado.valor != null) {
        _valorCtrl.text =
            interpretado.valor!.toStringAsFixed(2).replaceAll('.', ',');
      }
      _categoria = interpretado.categoria;
      if (interpretado.data != null) _data = interpretado.data!;
      if (interpretado.fornecedorNome != null) {
        _fornecedorCtrl.text = interpretado.fornecedorNome!;
      }
      _avisoIa = interpretado.valor == null
          ? 'Entendi a descrição, mas não o valor — confira o campo.'
          : 'Lançamento interpretado da sua fala — confira antes de salvar.';
      _leitura = _Leitura(
        origem: OrigemLancamento.voz,
        valor: interpretado.valor,
        fornecedor: interpretado.fornecedorNome,
        data: interpretado.data,
      );
      _leituraFalhou = false;
    });
  }

  void _verTextoLido() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TextoLido(texto: _textoOcr ?? ''),
    );
  }

  // ------------------------------------------------- Itens, foto e data

  /// Tira o item do estoque deste lançamento, com "Desfazer" por 4 s.
  void _removerItem(ItemMaterialModel item) {
    final posicao = _itens.indexOf(item);
    setState(() => _itens = List.of(_itens)..remove(item));
    mostrarAviso(
      context,
      '${item.resumo} não vai para o estoque.',
      aoDesfazer: () {
        if (!mounted || _itens.contains(item)) return;
        setState(() => _itens = List.of(_itens)
          ..insert(math.min(math.max(posicao, 0), _itens.length), item));
      },
    );
  }

  /// Desanexa a foto da nota, com "Desfazer" por 4 s.
  void _removerFoto() {
    final foto = _fotoNota;
    setState(() => _fotoNota = null);
    mostrarAviso(
      context,
      'A foto da nota não vai junto.',
      aoDesfazer: () {
        if (!mounted || _fotoNota != null) return;
        setState(() => _fotoNota = foto);
      },
    );
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  /// O "Salvar" fica no rodapé e o campo que falta pode estar lá em cima:
  /// rola até o primeiro campo com erro.
  void _mostrarPrimeiroErro() {
    final faltaDescricao =
        Validators.obrigatorio(_descricaoCtrl.text, 'A descrição') != null;
    final chave = faltaDescricao ? _chaveDescricao : _chaveValor;
    final alvo = chave.currentContext;
    if (alvo == null) return;
    unawaited(Scrollable.ensureVisible(
      alvo,
      alignment: 0.2,
      duration: context.duracao(Movimento.medio),
      curve: Movimento.entrar,
    ));
  }

  // ---------------------------------------------------------------- Salvar

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      unawaited(Tato.erro());
      _mostrarPrimeiroErro();
      return;
    }
    setState(() => _salvando = true);

    final db = context.read<FirestoreService>();
    final usuario = context.read<AuthProvider>().usuario!;

    try {
      final obra = await db.obra(widget.obraId).first;
      if (obra == null) {
        if (!mounted) return;
        setState(() => _salvando = false);
        unawaited(Tato.erro());
        mostrarAviso(
            context,
            'Esta obra não foi encontrada — ela pode ter sido '
            'removida. Volte e abra a obra de novo.');
        return;
      }

      String? fornecedorId;
      String? fornecedorNome;
      if (_fornecedorCtrl.text.trim().isNotEmpty) {
        final fornecedor = await db.obterOuCriarFornecedor(
          donoId: obra.donoId,
          nome: _fornecedorCtrl.text,
          cnpj: _cnpjExtraido,
        );
        fornecedorId = fornecedor.id;
        fornecedorNome = fornecedor.nome;
      }

      String? fotoDataUri;
      if (_fotoNota != null) {
        fotoDataUri = await ImagemService.comprimirParaDataUri(_fotoNota!);
      }

      // Lançamento manual de material: tenta extrair itens da descrição
      // para o estoque ("10 sacos de cimento" → +10 sc Cimento).
      var itens = _itens;
      if (itens.isEmpty && _categoria == CategoriaCusto.material) {
        itens = ItensParser.deTexto(_descricaoCtrl.text);
      }

      final lancamento = LancamentoModel(
        id: '',
        obraId: widget.obraId,
        descricao: _descricaoCtrl.text.trim(),
        valor: Formatters.parseValor(_valorCtrl.text)!,
        categoria: _categoria,
        // Lançamento do dono não precisa passar por aprovação.
        status: usuario.ehDono
            ? StatusLancamento.aprovado
            : StatusLancamento.pendente,
        origem: _origem,
        fornecedorId: fornecedorId,
        fornecedorNome: fornecedorNome,
        fotoNotaUrl: fotoDataUri,
        itens: itens,
        data: _data,
        criadoPorId: usuario.id,
        criadoPorNome: usuario.nome,
        aprovadoPorId: usuario.ehDono ? usuario.id : null,
        criadoEm: DateTime.now(),
      );
      await db.criarLancamento(lancamento);

      // Dono lança já aprovado → estoque é alimentado na hora.
      var resumoEstoque = const <String>[];
      if (usuario.ehDono && lancamento.itens.isNotEmpty) {
        resumoEstoque = await db.aplicarLancamentoNoEstoque(lancamento);
      }

      if (!mounted) return;
      unawaited(Tato.confirmar());
      // O aviso (e não o SnackBar direto): ele tira o "Desfazer" de um item
      // tirado agora há pouco, que senão seguraria esta confirmação por
      // até 4 s e iria junto para a tela de baixo, já sem efeito.
      mostrarAviso(
          context,
          usuario.ehDono
              ? (resumoEstoque.isEmpty
                  ? 'Lançamento registrado.'
                  : 'Registrado! Estoque atualizado: '
                      '${resumoEstoque.join(' · ')}')
              : 'Lançamento enviado para aprovação do dono.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      unawaited(Tato.erro());
      mostrarAviso(context, NovoLancamentoScreen.mensagemAoSalvar(e));
    }
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final leitura = _leitura;
    final estiloValor = Tipografia.valorHeroi.copyWith(
      fontSize: 32,
      height: 1.1,
      color: c.grafite,
    );
    return Scaffold(
      appBar: AppBar(title: _Titulo(obra: _obra)),
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Espaco.margem,
            Espaco.e8,
            Espaco.margem,
            Espaco.e32,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Captura primeiro: as duas escolhas grandes, lado a lado
                // e da mesma altura.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: BotaoIa(
                          icone: Icons.document_scanner_outlined,
                          rotulo: 'Foto da nota',
                          descricao: 'A câmera lê valor, data e loja',
                          onTap: _processando ? null : _lerNotaFiscal,
                        ),
                      ),
                      const SizedBox(width: Espaco.entreAlvos),
                      Expanded(
                        child: BotaoIa(
                          icone: Icons.mic_none,
                          rotulo: 'Falar o gasto',
                          descricao: 'Diga o que comprou e quanto',
                          onTap: _processando ? null : _lancarPorVoz,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_processando) ...[
                  const SizedBox(height: Espaco.e16),
                  _LendoANota(foto: _fotoEmLeitura),
                ],
                // A foto que não foi lida: o erro fica fora do recibo (que,
                // se houver, é o da leitura anterior) e é dito como erro.
                if (_avisoIa != null &&
                    (leitura == null || _leituraFalhou)) ...[
                  const SizedBox(height: Espaco.e16),
                  _FalhaDaLeitura(mensagem: _avisoIa!),
                ],
                if (leitura != null) ...[
                  const SizedBox(height: Espaco.e16),
                  _Recibo(
                    leitura: leitura,
                    aviso: _leituraFalhou ? null : _avisoIa,
                    itens: _itens,
                    foto: _fotoNota,
                    aoRemoverItem: _removerItem,
                    aoRemoverFoto: _removerFoto,
                    aoVerTextoLido: _textoOcr == null ? null : _verTextoLido,
                  ),
                ],
                const SizedBox(height: Espaco.e24),
                LinhaCota(
                  legenda: leitura == null
                      ? 'Ou preencha à mão'
                      : 'Confira e corrija',
                ),
                const SizedBox(height: Espaco.e16),
                TextFormField(
                  key: _chaveDescricao,
                  controller: _descricaoCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  // A descrição que vem da fala é comprida: quebra em até
                  // três linhas em vez de sumir pela direita. O "Enter"
                  // continua indo para o próximo campo (sem quebra de
                  // linha no texto).
                  minLines: 1,
                  maxLines: 3,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Ex.: 10 sacos de cimento CP-II',
                  ),
                  validator: (v) => Validators.obrigatorio(v, 'A descrição'),
                ),
                const SizedBox(height: Espaco.e16),
                TextFormField(
                  key: _chaveValor,
                  controller: _valorCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: estiloValor,
                  decoration: InputDecoration(
                    labelText: 'Valor',
                    prefixText: 'R\$ ',
                    prefixStyle: estiloValor,
                  ),
                  validator: Validators.valor,
                ),
                const SizedBox(height: Espaco.e24),
                SeletorGrande<CategoriaCusto>(
                  rotulo: 'Categoria',
                  opcoes: [
                    for (final cat in _ordemCategorias)
                      OpcaoSeletor(valor: cat, rotulo: cat.label),
                  ],
                  selecionado: _categoria,
                  aoMudar: (cat) => setState(() => _categoria = cat),
                ),
                const SizedBox(height: Espaco.e24),
                _CampoData(data: _data, aoTocar: _escolherData),
                const SizedBox(height: Espaco.e16),
                TextFormField(
                  controller: _fornecedorCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Fornecedor (opcional)',
                    hintText: 'Ex.: Depósito São José',
                    helperText: 'Se for novo, entra no cadastro sozinho.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BarraDeAcao(
        principal: BotaoPrincipal(
          rotulo: 'Salvar lançamento',
          icone: Icons.check,
          grande: true,
          carregando: _salvando,
          aoTocar: _salvar,
        ),
      ),
    );
  }
}

/// A ordem das categorias no seletor: a mais comum primeiro.
const _ordemCategorias = [
  CategoriaCusto.material,
  CategoriaCusto.maoDeObra,
  CategoriaCusto.equipamento,
  CategoriaCusto.outros,
];
