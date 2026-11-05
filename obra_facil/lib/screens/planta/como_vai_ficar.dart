import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../design/maquete/maquete.dart';
import '../../models/models.dart';
import '../../services/ia/planta_ia_service.dart';

/// Preço de uma imagem 4K do Nano Banana Pro (tabela do Google, nov/2026).
/// Só para avisar o dono antes de gerar; a conta real vem do Google.
const double precoImagemUsd = 0.24;

/// Fotografa o que está dentro do [RepaintBoundary] de [chave], em PNG.
/// Nulo quando não deu (fora da tela, ou o 3D saiu em branco).
Future<Uint8List?> capturarVista(GlobalKey chave, {double escala = 2}) async {
  final limite = chave.currentContext?.findRenderObject();
  if (limite is! RenderRepaintBoundary) return null;
  try {
    final imagem = await limite.toImage(pixelRatio: escala);
    try {
      final rgba = await imagem.toByteData();
      if (rgba == null || _emBranco(rgba)) return null;
      final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
      return png?.buffer.asUint8List();
    } finally {
      imagem.dispose();
    }
  } catch (_) {
    return null;
  }
}

/// Imagem de uma cor só: o 3D não entrou na captura.
bool _emBranco(ByteData rgba) {
  final total = rgba.lengthInBytes ~/ 4;
  if (total == 0) return true;
  final primeiro = rgba.getUint32(0);
  final passo = (total ~/ 997).clamp(1, total);
  for (var i = 0; i < total; i += passo) {
    if (rgba.getUint32(i * 4) != primeiro) return false;
  }
  return true;
}

/// O pedido de uma imagem "como vai ficar": a fachada (com a maquete ao
/// vivo, que o dono gira até o ângulo que quer) ou um cômodo (com o quadro
/// da vista 360° já capturado).
class PedidoImagem {
  const PedidoImagem.fachada()
      : vista = 'fachada',
        nomeComodo = null,
        medidas = null,
        piso = null,
        guia = null;

  const PedidoImagem.comodo({
    required this.vista,
    required String this.nomeComodo,
    required this.guia,
    this.medidas,
    this.piso,
  });

  final String vista;
  final String? nomeComodo;
  final String? medidas;
  final String? piso;

  /// O quadro do cômodo. Na fachada, a captura sai da maquete na hora.
  final Uint8List? guia;

  bool get ehFachada => vista == 'fachada';
}

/// Gerar a imagem: o ângulo (a maquete ou o quadro do cômodo), os detalhes
/// de acabamento, a ilustração do projeto (opcional) e o custo, antes de
/// gastar.
class GerarImagemScreen extends StatefulWidget {
  const GerarImagemScreen({
    super.key,
    required this.obraId,
    required this.pedido,
    this.maquete,
  });

  final String obraId;
  final PedidoImagem pedido;

  /// A maquete pronta, para a fachada.
  final Widget? maquete;

  @override
  State<GerarImagemScreen> createState() => _GerarImagemScreenState();
}

class _GerarImagemScreenState extends State<GerarImagemScreen> {
  final _chave = GlobalKey();
  final _detalhes = TextEditingController();
  Uint8List? _referencia;
  bool _gerando = false;
  String? _erro;
  ImagemGerada? _pronta;

  @override
  void dispose() {
    _detalhes.dispose();
    super.dispose();
  }

  Future<void> _escolherReferencia() async {
    final foto = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 88,
    );
    if (foto == null) return;
    final bytes = await foto.readAsBytes();
    if (mounted) setState(() => _referencia = bytes);
  }

  Future<void> _gerar() async {
    final ia = context.read<PlantaIaService>();
    setState(() {
      _gerando = true;
      _erro = null;
    });
    try {
      // Sem 3D, a maquete vira a planta desenhada: a fachada sairia errada.
      if (widget.pedido.guia == null && MaqueteObra.semSuporteGpu) {
        setState(() => _erro = 'Este aparelho não mostra a maquete em 3D, '
            'e a fachada sai dela. Gere num celular com 3D.');
        return;
      }
      final guia = widget.pedido.guia ?? await capturarVista(_chave);
      if (guia == null) {
        setState(() => _erro = 'Não deu para fotografar a maquete neste '
            'aparelho. Tente gerar pela vista 360° de um cômodo.');
        return;
      }
      final p = widget.pedido;
      final r = await ia.gerarImagem(
        obraId: widget.obraId,
        vista: p.vista,
        guia: guia,
        referencia: _referencia,
        referenciaTipo: _referencia == null ? null : 'image/jpeg',
        nomeComodo: p.nomeComodo,
        medidas: p.medidas,
        piso: p.piso,
        detalhes: _detalhes.text,
      );
      unawaited(Tato.confirmar());
      if (mounted) setState(() => _pronta = r);
    } on FalhaIaPlanta catch (f) {
      unawaited(Tato.erro());
      if (mounted) setState(() => _erro = f.mensagem);
    } catch (_) {
      unawaited(Tato.erro());
      if (mounted) {
        setState(() =>
            _erro = 'A imagem não saiu. Confira a internet e tente de novo.');
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final p = widget.pedido;
    final pronta = _pronta;
    final titulo = p.ehFachada ? 'A fachada' : p.nomeComodo!;
    final preco = precoImagemUsd.toStringAsFixed(2).replaceAll('.', ',');

    final Widget angulo = p.guia != null
        ? Image.memory(p.guia!, fit: BoxFit.cover, gaplessPlayback: true)
        : RepaintBoundary(key: _chave, child: widget.maquete);

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e32),
        children: [
          const Rotulo('Como vai ficar'),
          const SizedBox(height: Espaco.e4),
          Semantics(
            header: true,
            child: Text(titulo,
                style: Tipografia.tituloTela.copyWith(color: c.grafite)),
          ),
          const SizedBox(height: Espaco.e8),
          Text(
            pronta != null
                ? 'Pronta. Ela já aparece na planta da obra e para o cliente.'
                : p.ehFachada
                    ? 'Gire a maquete até o ângulo que quer ver. A IA pinta '
                        'por cima dela uma foto realista, com as mesmas '
                        'medidas.'
                    : 'A IA pinta por cima deste ângulo uma foto realista do '
                        'cômodo, com as mesmas medidas.',
            style: Tipografia.corpo.copyWith(color: c.grafite2),
          ),
          const SizedBox(height: Espaco.e16),
          Folha(
            preenchimento: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: Raio.cantoPequeno,
              child: AspectRatio(
                aspectRatio: p.ehFachada ? 3 / 2 : 4 / 3,
                child: pronta != null
                    ? _Foto(url: pronta.url)
                    : Varredura(
                        ativa: _gerando,
                        legenda: 'Gerando a imagem',
                        child: angulo,
                      ),
              ),
            ),
          ),
          if (_erro != null) ...[
            const SizedBox(height: Espaco.e12),
            NotaRevisao(_erro!, icone: Icons.error_outline),
          ],
          if (pronta == null) ...[
            const SizedBox(height: Espaco.e24),
            const LinhaCota(legenda: 'Acabamento (opcional)'),
            const SizedBox(height: Espaco.e12),
            TextField(
              controller: _detalhes,
              enabled: !_gerando,
              maxLines: 3,
              minLines: 2,
              maxLength: 600,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: p.ehFachada
                    ? 'Ex.: paredes brancas, ripado de madeira, portão preto'
                    : 'Ex.: piso amadeirado, paredes cinza-claro, cozinha '
                        'planejada branca',
              ),
            ),
            const SizedBox(height: Espaco.e8),
            if (_referencia == null)
              BotaoContorno(
                rotulo: 'Usar a ilustração do projeto',
                icone: Icons.image_outlined,
                expandir: true,
                aoTocar: _gerando ? null : () => unawaited(_escolherReferencia()),
              )
            else
              LinhaLista(
                inicio: ClipRRect(
                  borderRadius: Raio.cantoPequeno,
                  child: Image.memory(_referencia!,
                      width: 56, height: 56, fit: BoxFit.cover),
                ),
                titulo: 'Ilustração do projeto',
                apoio: 'A IA copia as cores e os materiais dela',
                fim: BotaoIcone(
                  icone: Icons.close,
                  rotulo: 'Tirar a ilustração',
                  aoTocar: () => setState(() => _referencia = null),
                ),
              ),
            const SizedBox(height: Espaco.e16),
            Text(
              'Cada imagem custa cerca de US\$ $preco (qualidade 4K) na '
              'conta do Google do projeto. Dá para gerar cada vista até 3 '
              'vezes.',
              style: Tipografia.apoio.copyWith(color: c.grafite2),
            ),
          ],
        ],
      ),
      bottomNavigationBar: BarraDeAcao(
        principal: pronta != null
            ? BotaoPrincipal(
                rotulo: 'Pronto',
                grande: true,
                expandir: true,
                aoTocar: () => Navigator.of(context).pop(pronta),
              )
            : BotaoPrincipal(
                rotulo: 'Gerar a imagem (US\$ $preco)',
                icone: Icons.auto_awesome_outlined,
                grande: true,
                expandir: true,
                carregando: _gerando,
                aoTocar: _gerando ? null : () => unawaited(_gerar()),
              ),
      ),
    );
  }
}

/// As imagens "como vai ficar" da obra, lado a lado. Tocar abre em tela
/// cheia, com zoom.
class GaleriaComoVaiFicar extends StatelessWidget {
  const GaleriaComoVaiFicar({super.key, required this.imagens});

  final List<ImagemIaModel> imagens;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imagens.length,
        separatorBuilder: (_, __) => const SizedBox(width: Espaco.e12),
        itemBuilder: (context, i) {
          final img = imagens[i];
          return AreaPressionavel(
            rotuloSemantico: 'Como vai ficar: ${img.nome}. Toque para ampliar.',
            aoTocar: () => unawaited(Navigator.of(context).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => _ImagemCheia(imagem: img),
              ),
            )),
            construtor: (context, _) => SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: Raio.cantoPequeno,
                      child: _Foto(url: img.url),
                    ),
                  ),
                  const SizedBox(height: Espaco.e4),
                  Text(
                    img.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tipografia.corpoForte.copyWith(color: c.grafite),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Foto extends StatelessWidget {
  const _Foto({required this.url, this.ajuste = BoxFit.cover});

  final String url;
  final BoxFit ajuste;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return ColoredBox(
      color: c.folhaRebaixada,
      child: Image.network(
        url,
        fit: ajuste,
        loadingBuilder: (context, filho, carga) => carga == null
            ? filho
            : const Center(child: IndicadorCarregando()),
        errorBuilder: (context, _, __) => Center(
          child: Icon(Icons.cloud_off_outlined, color: c.grafite2),
        ),
      ),
    );
  }
}

class _ImagemCheia extends StatelessWidget {
  const _ImagemCheia({required this.imagem});

  final ImagemIaModel imagem;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Scaffold(
      appBar: AppBar(title: Text(imagem.nome)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InteractiveViewer(
              maxScale: 6,
              child: _Foto(url: imagem.url, ajuste: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Espaco.margem),
            child: Text(
              'Imagem ilustrativa gerada por IA a partir da planta. As '
              'medidas valem as da planta; cores e acabamentos podem mudar.',
              style: Tipografia.apoio.copyWith(color: c.grafite2),
            ),
          ),
        ],
      ),
    );
  }
}
