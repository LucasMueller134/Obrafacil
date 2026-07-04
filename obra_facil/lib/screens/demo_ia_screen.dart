import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';
import '../services/ia/material_vision_service.dart';
import '../services/ia/ocr_nota_service.dart';
import '../services/ia/voz_service.dart';
import '../utils/formatters.dart';
import '../widgets/painel_voz.dart';

/// Demonstração das IAs on-device — funciona sem login e sem internet.
/// Acessível pela tela de configuração pendente, para testar o app
/// antes mesmo de conectar o Firebase.
class DemoIaScreen extends StatefulWidget {
  const DemoIaScreen({super.key});

  @override
  State<DemoIaScreen> createState() => _DemoIaScreenState();
}

class _DemoIaScreenState extends State<DemoIaScreen> {
  final _ocr = OcrNotaService();
  final _voz = VozService();

  NotaFiscalExtraida? _nota;
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
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Tirar foto da nota'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origem == null) return;
    final xfile = await ImagePicker()
        .pickImage(source: origem, imageQuality: 92, maxWidth: 2200);
    if (xfile == null || !mounted) return;

    setState(() => _lendoNota = true);
    try {
      final nota = await _ocr.lerNota(xfile.path);
      if (mounted) setState(() => _nota = nota);
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
    final xfile = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 90, maxWidth: 1600);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Demonstração das IAs')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
        children: [
          Text(
            'Os quatro módulos de IA do ObraFácil rodam dentro do celular, '
            'sem internet. Teste três deles aqui — sem precisar de conta.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textoSecundario),
          ),
          const SizedBox(height: 16),

          // ------------------------------------------------------- OCR
          _CartaoDemo(
            icone: Icons.document_scanner,
            titulo: 'OCR de nota fiscal',
            descricao: 'Fotografe uma nota ou cupom fiscal — o app extrai '
                'fornecedor, CNPJ, total e data.',
            botao: 'Ler nota',
            carregando: _lendoNota,
            onPressed: _demonstrarOcr,
            resultado: _nota == null
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Linha('Fornecedor', _nota!.fornecedorNome ?? '—'),
                      _Linha('CNPJ', _nota!.cnpj ?? '—'),
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
                      if (!_nota!.encontrouAlgo)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Nada reconhecido — tente uma foto mais nítida, '
                            'bem iluminada e sem inclinação.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.alerta),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // ------------------------------------------------------- Voz
          _CartaoDemo(
            icone: Icons.mic,
            titulo: 'Lançamento por voz',
            descricao: 'Diga algo como "comprei dez sacos de cimento por '
                'trezentos e cinquenta reais no Depósito São José" — '
                'a interpretação acontece ao vivo enquanto você fala.',
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
                            style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: AppColors.amareloCapacete),
                          ),
                        ),
                      if (_interpretado != null) ...[
                        _Linha('Descrição', _interpretado!.descricao),
                        _Linha(
                            'Valor',
                            _interpretado!.valor != null
                                ? Formatters.moeda(_interpretado!.valor!)
                                : '—'),
                        _Linha('Categoria', _interpretado!.categoria.label),
                        _Linha('Fornecedor',
                            _interpretado!.fornecedorNome ?? '—'),
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
          const SizedBox(height: 12),

          // ----------------------------------------------------- Visão
          _CartaoDemo(
            icone: Icons.camera_alt,
            titulo: 'Reconhecimento de material',
            descricao: 'Aponte a câmera para um material de construção '
                '(tijolo, madeira, cano...) e veja a classificação.',
            botao: 'Fotografar material',
            carregando: _reconhecendo,
            onPressed: _demonstrarVisao,
            resultado: _materiais == null
                ? null
                : _materiais!.isEmpty
                    ? const Text(
                        'Nenhum material de construção reconhecido nesta foto.',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.alerta),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final m in _materiais!)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(child: Text(m.material)),
                                  SizedBox(
                                    width: 90,
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: m.confianca,
                                        minHeight: 8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(m.confianca * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
          ),
          const SizedBox(height: 16),
          Text(
            'O 4º módulo — previsão de estouro de orçamento por regressão — '
            'aparece no dashboard da obra depois que o Firebase for conectado '
            'e houver lançamentos aprovados.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textoDesabilitado),
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
    return Container(
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
              Icon(icone, color: AppColors.laranja),
              const SizedBox(width: 10),
              Expanded(
                child: Text(titulo,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(descricao,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textoSecundario)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: carregando ? null : onPressed,
            child: carregando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(botao),
          ),
          if (resultado != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.fundo,
                borderRadius: BorderRadius.circular(12),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(rotulo,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textoSecundario)),
          ),
          Expanded(
            child: Text(valor,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
