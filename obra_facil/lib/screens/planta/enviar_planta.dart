import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../design/maquete/maquete.dart';
import '../../models/models.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/planta_ia_service.dart';
import 'ficha_comodo.dart';

/// O arquivo da planta escolhido pelo dono.
class ArquivoPlanta {
  const ArquivoPlanta(this.bytes, this.nome, {this.tipo});

  final Uint8List bytes;
  final String nome;
  final String? tipo;

  bool get ehImagem {
    final n = nome.toLowerCase();
    return tipo?.startsWith('image/') == true ||
        ['.jpg', '.jpeg', '.png', '.webp', '.heic'].any(n.endsWith);
  }
}

/// Abre a escolha da planta (foto ou arquivo) e, com ela, a leitura.
Future<void> enviarPlanta(BuildContext context, String obraId) async {
  final arquivo = await showModalBottomSheet<ArquivoPlanta>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _EscolherArquivo(),
  );
  if (arquivo == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => TemaPrancheta(
      child: LeituraPlantaScreen(obraId: obraId, arquivo: arquivo),
    ),
  ));
}

class _EscolherArquivo extends StatefulWidget {
  const _EscolherArquivo();

  @override
  State<_EscolherArquivo> createState() => _EscolherArquivoState();
}

class _EscolherArquivoState extends State<_EscolherArquivo> {
  bool _abrindo = false;

  Future<void> _foto() async {
    setState(() => _abrindo = true);
    try {
      final foto = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 4000,
        imageQuality: 88,
      );
      if (foto == null || !mounted) return;
      final bytes = await foto.readAsBytes();
      if (mounted) {
        Navigator.pop(context, ArquivoPlanta(bytes, foto.name, tipo: 'image/jpeg'));
      }
    } finally {
      if (mounted) setState(() => _abrindo = false);
    }
  }

  Future<void> _arquivo() async {
    setState(() => _abrindo = true);
    try {
      final r = await FilePicker.platform.pickFiles(withData: true);
      final f = r?.files.singleOrNull;
      if (f?.bytes == null || !mounted) return;
      Navigator.pop(context, ArquivoPlanta(f!.bytes!, f.name));
    } finally {
      if (mounted) setState(() => _abrindo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            Espaco.margem, Espaco.e8, Espaco.margem, Espaco.e16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Rotulo('Planta da obra'),
            const SizedBox(height: Espaco.e4),
            Text('Enviar a planta',
                style: Tipografia.titulo.copyWith(color: c.grafite)),
            const SizedBox(height: Espaco.e8),
            Text(
              'Qualquer formato: foto da planta impressa, PDF, imagem ou o '
              'DXF do CAD. A IA lê as paredes, os vãos e os cômodos, e você '
              'confere antes de confirmar.',
              style: Tipografia.corpo.copyWith(color: c.grafite2),
            ),
            const SizedBox(height: Espaco.e16),
            BotaoPrincipal(
              rotulo: 'Escolher arquivo',
              icone: Icons.upload_file_outlined,
              grande: true,
              expandir: true,
              carregando: _abrindo,
              aoTocar: _abrindo ? null : () => unawaited(_arquivo()),
            ),
            const SizedBox(height: Espaco.entreAlvos),
            BotaoContorno(
              rotulo: 'Tirar foto da planta',
              icone: Icons.photo_camera_outlined,
              expandir: true,
              aoTocar: _abrindo ? null : () => unawaited(_foto()),
            ),
            const SizedBox(height: Espaco.e12),
            Text(
              'DWG não dá: é um formato fechado. No CAD, exporte em PDF ou '
              'DXF.',
              style: Tipografia.apoio.copyWith(color: c.grafite2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Foto grande demais (o limite da chamada é ~9 MB): reduz o lado maior
/// para 3.500 px e regrava em JPEG. PDF e DXF vão como estão.
Uint8List _reduzir(Uint8List bytes) {
  final imagem = img.decodeImage(bytes);
  if (imagem == null) return bytes;
  final menor = imagem.width >= imagem.height
      ? img.copyResize(imagem, width: 3500)
      : img.copyResize(imagem, height: 3500);
  return Uint8List.fromList(img.encodeJpg(menor, quality: 85));
}

/// Enquanto a IA lê: a planta com a varredura passando. Depois, a revisão.
class LeituraPlantaScreen extends StatefulWidget {
  const LeituraPlantaScreen({
    super.key,
    required this.obraId,
    required this.arquivo,
  });

  final String obraId;
  final ArquivoPlanta arquivo;

  @override
  State<LeituraPlantaScreen> createState() => _LeituraPlantaScreenState();
}

class _LeituraPlantaScreenState extends State<LeituraPlantaScreen> {
  FalhaIaPlanta? _falha;

  @override
  void initState() {
    super.initState();
    unawaited(_ler());
  }

  Future<void> _ler() async {
    setState(() => _falha = null);
    final ia = context.read<PlantaIaService>();
    var bytes = widget.arquivo.bytes;
    if (widget.arquivo.ehImagem && bytes.length > 6 * 1024 * 1024) {
      bytes = await compute(_reduzir, bytes);
    }
    try {
      final leitura = await ia.lerPlanta(
        obraId: widget.obraId,
        bytes: bytes,
        nome: widget.arquivo.nome,
        tipo: widget.arquivo.tipo,
      );
      if (!mounted) return;
      unawaited(Tato.confirmar());
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => TemaPrancheta(
          child: RevisaoPlantaScreen(
            obraId: widget.obraId,
            leitura: leitura,
            arquivo: widget.arquivo,
          ),
        ),
      ));
    } on FalhaIaPlanta catch (f) {
      unawaited(Tato.erro());
      if (mounted) setState(() => _falha = f);
    } catch (e) {
      unawaited(Tato.erro());
      if (mounted) {
        setState(() => _falha =
            const FalhaIaPlanta('A leitura falhou. Confira a internet e tente de novo.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final falha = _falha;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(Espaco.margem),
        children: [
          const Rotulo('Planta da obra'),
          const SizedBox(height: Espaco.e4),
          Text(falha == null ? 'Lendo a planta' : 'A leitura não deu certo',
              style: Tipografia.tituloTela.copyWith(color: c.grafite)),
          const SizedBox(height: Espaco.e8),
          Text(
            falha?.mensagem ??
                'A IA está medindo as paredes, os vãos e os cômodos. Leva '
                    'um ou dois minutos.',
            style: Tipografia.corpo.copyWith(color: c.grafite2),
          ),
          const SizedBox(height: Espaco.e24),
          Folha(
            preenchimento: EdgeInsets.zero,
            child: SizedBox(
              height: 320,
              child: Varredura(
                ativa: falha == null,
                legenda: 'Lendo a planta',
                child: widget.arquivo.ehImagem
                    ? Image.memory(widget.arquivo.bytes, fit: BoxFit.contain)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.description_outlined,
                                size: 48, color: c.grafite),
                            const SizedBox(height: Espaco.e8),
                            Text(widget.arquivo.nome,
                                style: Tipografia.corpoForte
                                    .copyWith(color: c.grafite)),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: falha == null
          ? null
          : BarraDeAcao(
              // Sem a função publicada, tentar de novo não adianta.
              principal: falha.naoPublicada
                  ? BotaoContorno(
                      rotulo: 'Voltar',
                      expandir: true,
                      aoTocar: () => Navigator.of(context).pop(),
                    )
                  : BotaoPrincipal(
                      rotulo: 'Tentar de novo',
                      icone: Icons.refresh,
                      grande: true,
                      expandir: true,
                      aoTocar: () => unawaited(_ler()),
                    ),
            ),
    );
  }
}

/// A revisão da leitura: a planta lida, o original e o 3D, os avisos da IA
/// e os ajustes que o dono faz aqui (nome, cobertura e piso dos cômodos,
/// pé-direito). Só depois de confirmar a planta vai para a obra.
class RevisaoPlantaScreen extends StatefulWidget {
  const RevisaoPlantaScreen({
    super.key,
    required this.obraId,
    required this.leitura,
    this.arquivo,
  });

  final String obraId;
  final LeituraPlanta leitura;
  final ArquivoPlanta? arquivo;

  @override
  State<RevisaoPlantaScreen> createState() => _RevisaoPlantaScreenState();
}

enum _Vista { leitura, original, tresD }

class _RevisaoPlantaScreenState extends State<RevisaoPlantaScreen> {
  late PlantaObra _planta = widget.leitura.planta;
  _Vista _vista = _Vista.leitura;
  bool _salvando = false;

  PlantaObra _com({AlturasPlanta? alturas, List<ComodoPlanta>? comodos}) =>
      PlantaObra(
        versao: _planta.versao,
        nome: _planta.nome,
        fonte: _planta.fonte,
        largura: _planta.largura,
        profundidade: _planta.profundidade,
        alturas: alturas ?? _planta.alturas,
        cobertura: _planta.cobertura,
        paredes: _planta.paredes,
        pilares: _planta.pilares,
        comodos: comodos ?? _planta.comodos,
      );

  void _peDireito(double delta) {
    final a = _planta.alturas;
    final novo = ((a.peDireito + delta) * 100).round() / 100;
    if (novo < 2.2 || novo > 4.5) return;
    unawaited(Tato.leve());
    setState(() => _planta = _com(
        alturas: AlturasPlanta(peDireito: novo, porta: a.porta, muro: a.muro)));
  }

  Future<void> _editar(ComodoPlanta c) async {
    final novo = await showModalBottomSheet<ComodoPlanta>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditarComodo(comodo: c),
    );
    if (novo == null) return;
    setState(() => _planta = _com(comodos: [
          for (final x in _planta.comodos) x.id == c.id ? novo : x,
        ]));
  }

  Future<void> _confirmar() async {
    setState(() => _salvando = true);
    final db = context.read<FirestoreService>();
    try {
      await db.salvarPlanta(widget.obraId, _planta);
      unawaited(Tato.confirmar());
      if (!mounted) return;
      mostrarAviso(context,
          'Planta confirmada. A maquete da obra já é esta casa.');
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final problemas = _planta.problemas();
    final vaos = _planta.paredes.fold<int>(0, (s, w) => s + w.aberturas.length);
    final comodos = [..._planta.comodos]
      ..sort((a, b) => (b.coberto ? 1 : 0).compareTo(a.coberto ? 1 : 0));
    final numeros = {for (var i = 0; i < comodos.length; i++) comodos[i].id: i + 1};
    String m(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

    final Widget vista = switch (_vista) {
      _Vista.leitura => LayoutBuilder(
          builder: (context, caixa) => SizedBox(
            height: PlantaDesenhada.alturaPara(_planta, caixa.maxWidth),
            child: PlantaDesenhada(
              planta: _planta,
              numeros: numeros,
              aoTocarComodo: (x) => unawaited(_editar(x)),
            ),
          ),
        ),
      _Vista.original => SizedBox(
          height: 320,
          child: widget.arquivo?.ehImagem == true
              ? InteractiveViewer(
                  maxScale: 5,
                  child: Image.memory(widget.arquivo!.bytes, fit: BoxFit.contain),
                )
              : Center(
                  child: Text(widget.arquivo?.nome ?? 'Arquivo enviado',
                      style: Tipografia.corpo.copyWith(color: c.grafite2)),
                ),
        ),
      _Vista.tresD => MaqueteObra(
          progresso: ProgressoMaquete.fases(
              List<double>.filled(ProgressoMaquete.totalFases, 1)),
          altura: 280,
          legenda: false,
          fonte: problemas.isEmpty ? FontePlanta(_planta) : FonteMaquete.padrao,
        ),
    };

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e32),
        children: [
          Carimbo(linhas: [
            [
              CelulaCarimbo(
                rotulo: 'Revisão da planta',
                conteudo: Text(
                  'Confira antes de confirmar',
                  style: Tipografia.titulo.copyWith(color: c.grafite),
                ),
              ),
            ],
            [
              CelulaCarimbo(
                rotulo: 'Construído',
                valor: '${_planta.areaConstruida.toStringAsFixed(0)} m²',
              ),
              CelulaCarimbo(
                rotulo: 'Terreno',
                valor: '${m(_planta.largura)} × ${m(_planta.profundidade)} m',
              ),
            ],
            [
              CelulaCarimbo(rotulo: 'Cômodos', valor: '${_planta.comodos.length}'),
              CelulaCarimbo(
                rotulo: 'Paredes e vãos',
                valor: '${_planta.paredes.length} · $vaos',
              ),
            ],
          ]),
          const SizedBox(height: Espaco.e16),
          Text(
            'A IA erra medida. Compare a leitura com o original: a maquete, a '
            'planta do cliente e a vista 360° saem daqui.',
            style: Tipografia.corpo.copyWith(color: c.grafite2),
          ),
          const SizedBox(height: Espaco.e16),
          SeletorGrande<_Vista>(
            opcoes: const [
              OpcaoSeletor(valor: _Vista.leitura, rotulo: 'Leitura'),
              OpcaoSeletor(valor: _Vista.original, rotulo: 'Original'),
              OpcaoSeletor(valor: _Vista.tresD, rotulo: '3D'),
            ],
            selecionado: _vista,
            aoMudar: (v) => setState(() => _vista = v),
          ),
          const SizedBox(height: Espaco.e12),
          Folha(preenchimento: EdgeInsets.zero, child: vista),
          if (problemas.isNotEmpty || widget.leitura.avisos.isNotEmpty) ...[
            const SizedBox(height: Espaco.e24),
            const LinhaCota(legenda: 'Para conferir'),
            const SizedBox(height: Espaco.e12),
            for (final p in problemas) ...[
              NotaRevisao(p, icone: Icons.error_outline),
              const SizedBox(height: Espaco.e8),
            ],
            for (final a in widget.leitura.avisos) ...[
              NotaRevisao(a, tipo: TipoNota.marca, icone: Icons.info_outline),
              const SizedBox(height: Espaco.e8),
            ],
          ],
          const SizedBox(height: Espaco.e24),
          const LinhaCota(legenda: 'Pé-direito'),
          const SizedBox(height: Espaco.e12),
          Row(
            children: [
              BotaoIcone(
                icone: Icons.remove,
                rotulo: 'Menos 5 cm',
                aoTocar: () => _peDireito(-0.05),
              ),
              Expanded(
                child: Text(
                  '${m(_planta.alturas.peDireito)} m',
                  textAlign: TextAlign.center,
                  style: Tipografia.titulo.copyWith(
                    color: c.grafite,
                    fontFeatures: Tipografia.tabular,
                  ),
                ),
              ),
              BotaoIcone(
                icone: Icons.add,
                rotulo: 'Mais 5 cm',
                aoTocar: () => _peDireito(0.05),
              ),
            ],
          ),
          const SizedBox(height: Espaco.e24),
          LinhaCota(legenda: '${comodos.length} cômodos'),
          const SizedBox(height: Espaco.e12),
          Folha(
            preenchimento: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < comodos.length; i++)
                  LinhaLista(
                    inicio: NumeroDeLegenda(i + 1),
                    titulo: comodos[i].nome,
                    apoio: '${medidasDoComodo(comodos[i])} · '
                        '${comodos[i].coberto ? comodos[i].piso.rotulo : 'descoberto'}',
                    valor: areaDoComodo(comodos[i]),
                    margemHorizontal: Espaco.e12,
                    divisoria: i < comodos.length - 1,
                    aoTocar: () => unawaited(_editar(comodos[i])),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Espaco.e8),
          Text(
            'Toque num cômodo para corrigir o nome, a cobertura ou o piso. '
            'Medida errada: tire uma foto mais nítida ou envie o PDF e leia '
            'de novo.',
            style: Tipografia.apoio.copyWith(color: c.grafite2),
          ),
        ],
      ),
      bottomNavigationBar: BarraDeAcao(
        acima: problemas.isEmpty
            ? null
            : Text('Corrija os itens em vermelho para confirmar.',
                style: Tipografia.apoio.copyWith(color: c.revisao)),
        principal: BotaoPrincipal(
          rotulo: 'Confirmar a planta',
          grande: true,
          expandir: true,
          carregando: _salvando,
          aoTocar: problemas.isEmpty && !_salvando
              ? () => unawaited(_confirmar())
              : null,
        ),
      ),
    );
  }
}

class _EditarComodo extends StatefulWidget {
  const _EditarComodo({required this.comodo});

  final ComodoPlanta comodo;

  @override
  State<_EditarComodo> createState() => _EditarComodoState();
}

class _EditarComodoState extends State<_EditarComodo> {
  late final _nome = TextEditingController(text: widget.comodo.nome);
  late bool _coberto = widget.comodo.coberto;
  late PisoComodo _piso = widget.comodo.piso;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Padding(
      padding: EdgeInsets.only(
        left: Espaco.margem,
        right: Espaco.margem,
        top: Espaco.e8,
        bottom: MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.viewPaddingOf(context).bottom +
            Espaco.e16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Rotulo('Cômodo'),
            const SizedBox(height: Espaco.e4),
            Text(medidasDoComodo(widget.comodo),
                style: Tipografia.titulo.copyWith(color: c.grafite)),
            const SizedBox(height: Espaco.e16),
            TextField(
              controller: _nome,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: Espaco.e16),
            SeletorGrande<bool>(
              rotulo: 'Cobertura',
              opcoes: const [
                OpcaoSeletor(valor: true, rotulo: 'Com laje'),
                OpcaoSeletor(valor: false, rotulo: 'Descoberto'),
              ],
              selecionado: _coberto,
              aoMudar: (v) => setState(() => _coberto = v),
            ),
            const SizedBox(height: Espaco.e16),
            const Rotulo('Piso'),
            const SizedBox(height: Espaco.e8),
            Wrap(
              spacing: Espaco.e8,
              runSpacing: Espaco.e8,
              children: [
                for (final p in PisoComodo.values)
                  ChoiceChip(
                    label: Text(p.rotulo),
                    selected: _piso == p,
                    onSelected: (_) => setState(() => _piso = p),
                  ),
              ],
            ),
            const SizedBox(height: Espaco.e24),
            BotaoPrincipal(
              rotulo: 'Salvar o cômodo',
              grande: true,
              expandir: true,
              aoTocar: () => Navigator.pop(
                context,
                ComodoPlanta(
                  id: widget.comodo.id,
                  nome: _nome.text.trim().isEmpty
                      ? widget.comodo.nome
                      : _nome.text.trim(),
                  tipo: widget.comodo.tipo,
                  coberto: _coberto,
                  piso: _piso,
                  retangulos: widget.comodo.retangulos,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
