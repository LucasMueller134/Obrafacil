import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../design/design.dart';
import '../services/ia/material_vision_service.dart';
import '../services/ia/ocr_nota_service.dart';
import '../services/ia/voz_service.dart';
import '../utils/formatters.dart';
import '../widgets/painel_voz.dart';

/// Demonstração das IAs on-device — funciona sem login e sem internet.
/// Acessível pela tela de configuração pendente, para testar o app
/// antes mesmo de conectar o Firebase.
class DemoIaScreen extends StatelessWidget {
  const DemoIaScreen({super.key});

  @override
  Widget build(BuildContext context) => const TemaPrancheta(child: _DemoIa());
}

class _DemoIa extends StatefulWidget {
  const _DemoIa();

  @override
  State<_DemoIa> createState() => _DemoIaScreenState();
}

class _DemoIaScreenState extends State<_DemoIa> {
  final _ocr = OcrNotaService();
  final _voz = VozService();

  NotaFiscalExtraida? _nota;
  String? _erroNota;
  bool _lendoNota = false;

  String _transcricao = '';
  LancamentoPorVoz? _interpretado;

  List<MaterialDetectado>? _materiais;
  bool _reconhecendo = false;

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  Future<void> _demonstrarOcr() async {
    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinhaLista(
              icone: Icons.photo_camera_outlined,
              titulo: 'Tirar foto da nota',
              divisoria: true,
              aoTocar: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            LinhaLista(
              icone: Icons.photo_library_outlined,
              titulo: 'Escolher da galeria',
              aoTocar: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origem == null) return;
    final xfile = await ImagePicker()
        .pickImage(source: origem, imageQuality: 92, maxWidth: 2200);
    if (xfile == null || !mounted) return;

    setState(() {
      _lendoNota = true;
      _erroNota = null;
    });
    try {
      final nota = await _ocr.lerNota(xfile.path);
      if (mounted) setState(() => _nota = nota);
    } catch (e) {
      // Sem o catch, a falha do leitor sumia em silêncio e o botão só
      // voltava ao normal; a mensagem diz o que tentar.
      if (mounted) {
        setState(() {
          _nota = null;
          _erroNota = OcrNotaService.mensagemDeErro(e);
        });
      }
    } finally {
      if (mounted) setState(() => _lendoNota = false);
    }
  }

  Future<void> _demonstrarVoz() async {
    final resultado = await mostrarPainelVoz(context, _voz);
    if (!mounted || resultado == null) return;
    setState(() {
      _transcricao = resultado.transcricao;
      _interpretado = resultado;
    });
  }

  Future<void> _demonstrarVisao() async {
    final xfile = await ImagePicker().pickImage(
        source: ImageSource.camera, imageQuality: 90, maxWidth: 1600);
    if (xfile == null || !mounted) return;

    setState(() => _reconhecendo = true);
    final visao = MaterialVisionService();
    try {
      final detectados = await visao.reconhecer(xfile.path);
      if (mounted) setState(() => _materiais = detectados);
    } finally {
      visao.dispose();
      if (mounted) setState(() => _reconhecendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final alerta = Tipografia.apoio
        .copyWith(color: c.revisao, fontWeight: FontWeight.w700);
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e32),
        children: [
          const Rotulo('Demonstração'),
          const SizedBox(height: Espaco.e4),
          Text('As IAs do Obra na Mão',
              style: Tipografia.tituloTela.copyWith(color: c.grafite)),
          const SizedBox(height: Espaco.e8),
          Text(
            'Os quatro módulos de IA do Obra na Mão rodam dentro do celular, '
            'sem internet. Teste três deles aqui, sem precisar de conta.',
            style: Tipografia.corpo.copyWith(color: c.grafite2),
          ),
          const SizedBox(height: Espaco.e24),

          // ------------------------------------------------------- OCR
          _CartaoDemo(
            icone: Icons.document_scanner_outlined,
            titulo: 'OCR de nota fiscal',
            descricao: 'Fotografe uma nota ou cupom fiscal: o app extrai '
                'fornecedor, CNPJ, total e data.',
            botao: 'Ler nota',
            carregando: _lendoNota,
            onPressed: _demonstrarOcr,
            resultado: _erroNota != null
                ? Text(_erroNota!, style: alerta)
                : _nota == null
                    ? null
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Linha('Fornecedor', _nota!.fornecedorNome ?? '—'),
                          _Linha(
                              'CNPJ',
                              _nota!.cnpj == null
                                  ? '—'
                                  : _nota!.cnpjDaChave
                                      ? '${_nota!.cnpj} (da chave de acesso)'
                                      : _nota!.cnpj!),
                          _Linha(
                              'Total',
                              _nota!.valorTotal != null
                                  ? Formatters.moeda(_nota!.valorTotal!)
                                  : '—'),
                          _Linha(
                              'Data',
                              _nota!.data != null
                                  ? Formatters.data(_nota!.data!)
                                  : '—'),
                          if (_nota!.chaveAcesso != null)
                            _Linha(
                                'Chave de acesso',
                                ChaveAcesso.validar(_nota!.chaveAcesso!)
                                        ?.formatada ??
                                    _nota!.chaveAcesso!),
                          if (!_nota!.encontrouAlgo)
                            Padding(
                              padding: const EdgeInsets.only(top: Espaco.e8),
                              child: Text(
                                'Nada reconhecido. Tente uma foto mais nítida, '
                                'bem iluminada e sem inclinação.',
                                style: alerta,
                              ),
                            ),
                        ],
                      ),
          ),
          const SizedBox(height: Espaco.e16),

          // ------------------------------------------------------- Voz
          _CartaoDemo(
            icone: Icons.mic_none,
            titulo: 'Lançamento por voz',
            descricao: 'Diga algo como "comprei dez sacos de cimento por '
                'trezentos e cinquenta reais no Depósito São José". '
                'A interpretação acontece ao vivo enquanto você fala.',
            botao: 'Falar',
            carregando: false,
            onPressed: _demonstrarVoz,
            resultado: _transcricao.isEmpty && _interpretado == null
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_transcricao.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '"$_transcricao"',
                            style: Tipografia.corpo.copyWith(
                                fontStyle: FontStyle.italic, color: c.grafite),
                          ),
                        ),
                      if (_interpretado != null) ...[
                        _Linha('Descrição', _interpretado!.descricao),
                        _Linha(
                            'Valor',
                            _interpretado!.valor != null
                                ? Formatters.moeda(_interpretado!.valor!)
                                : '—'),
                        _Linha(
                            'Data',
                            _interpretado!.data != null
                                ? Formatters.data(_interpretado!.data!)
                                : '—'),
                        _Linha('Categoria', _interpretado!.categoria.label),
                        _Linha(
                            'Fornecedor', _interpretado!.fornecedorNome ?? '—'),
                        if (_interpretado!.itens.isNotEmpty)
                          _Linha(
                              'Materiais',
                              _interpretado!.itens
                                  .map((i) => i.resumo)
                                  .join(' · ')),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: Espaco.e16),

          // ----------------------------------------------------- Visão
          _CartaoDemo(
            icone: Icons.photo_camera_outlined,
            titulo: 'Reconhecimento de material',
            descricao: 'Aponte a câmera para um material de construção '
                '(tijolo, madeira, cano...) e veja a classificação.',
            botao: 'Fotografar material',
            carregando: _reconhecendo,
            onPressed: _demonstrarVisao,
            resultado: _materiais == null
                ? null
                : _materiais!.isEmpty
                    ? Text(
                        'Nenhum material de construção reconhecido nesta foto.',
                        style: alerta,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final m in _materiais!)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                      child: Text(m.material,
                                          style: Tipografia.corpo
                                              .copyWith(color: c.grafite))),
                                  SizedBox(
                                    width: 90,
                                    child: ReguaCota(valor: m.confianca),
                                  ),
                                  const SizedBox(width: Espaco.e8),
                                  Text(
                                    '${(m.confianca * 100).toStringAsFixed(0)}%',
                                    style: Tipografia.corpoForte.copyWith(
                                        color: c.grafite,
                                        fontFeatures: Tipografia.tabular),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
          ),
          const SizedBox(height: 16),
          Text(
            'O 4º módulo, a previsão de estouro do orçamento por regressão, '
            'aparece na central da obra depois que o Firebase for conectado '
            'e houver lançamentos aprovados.',
            style: Tipografia.apoio.copyWith(color: c.grafite2),
          ),
        ],
      ),
    );
  }
}

class _CartaoDemo extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String descricao;
  final String botao;
  final bool carregando;
  final VoidCallback onPressed;
  final Widget? resultado;

  const _CartaoDemo({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.botao,
    required this.carregando,
    required this.onPressed,
    this.resultado,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Folha(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icone, color: c.grafite),
              const SizedBox(width: Espaco.e8),
              Expanded(
                child: Text(titulo,
                    style: Tipografia.subtitulo.copyWith(color: c.grafite)),
              ),
            ],
          ),
          const SizedBox(height: Espaco.e8),
          Text(descricao, style: Tipografia.apoio.copyWith(color: c.grafite2)),
          const SizedBox(height: Espaco.e12),
          BotaoContorno(
            rotulo: botao,
            expandir: true,
            carregando: carregando,
            aoTocar: carregando ? null : onPressed,
          ),
          if (resultado != null) ...[
            const SizedBox(height: Espaco.e12),
            Container(
              padding: const EdgeInsets.all(Espaco.e12),
              decoration: BoxDecoration(
                color: c.folhaRebaixada,
                borderRadius: Raio.cantoPequeno,
              ),
              child: resultado,
            ),
          ],
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  final String rotulo;
  final String valor;

  const _Linha(this.rotulo, this.valor);

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espaco.e4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Rotulo(rotulo),
          Text(valor, style: Tipografia.corpoForte.copyWith(color: c.grafite)),
        ],
      ),
    );
  }
}
