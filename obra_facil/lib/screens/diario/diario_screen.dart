import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../design/design.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/cores_foto.dart';
import '../../services/ia/diario_foto_service.dart';
import '../../services/ia/mensagens_erro.dart';
import '../../services/ia/modelo_fases.dart';
import '../../services/ia/voz_service.dart';
import '../../services/imagem_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/botao_ia.dart';
import '../../widgets/imagem_obra.dart';
import '../../widgets/painel_voz.dart';

/// O diário de obra: o que aconteceu no canteiro, dia a dia (atividades,
/// equipe, clima, fase e fotos). Registrar dá para ditar por voz ou deixar
/// a IA ler a foto do canteiro.
class DiarioScreen extends StatelessWidget {
  final String obraId;

  const DiarioScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) =>
      TemaPrancheta(child: _Diario(obraId: obraId));
}

class _Diario extends StatefulWidget {
  const _Diario({required this.obraId});

  final String obraId;

  @override
  State<_Diario> createState() => _DiarioState();
}

class _DiarioState extends State<_Diario> {
  late final Stream<List<DiarioEntradaModel>> _diario =
      context.read<FirestoreService>().diario(widget.obraId);
  late final Stream<ObraModel?> _obra =
      context.read<FirestoreService>().obra(widget.obraId);

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Scaffold(
      appBar: AppBar(),
      body: StreamBuilder<List<DiarioEntradaModel>>(
        stream: _diario,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(Espaco.margem),
              children: const [
                EsqueletoFolha(linhas: 3, rotuloSemantico: 'Abrindo o diário'),
              ],
            );
          }
          final entradas = snapshot.data ?? const <DiarioEntradaModel>[];
          final ultimo = entradas.isEmpty ? null : entradas.first.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e32),
            children: [
              StreamBuilder<ObraModel?>(
                stream: _obra,
                builder: (context, obra) => Carimbo(linhas: [
                  [
                    CelulaCarimbo(
                      rotulo: 'Diário de obra',
                      conteudo: Semantics(
                        header: true,
                        child: Text(
                          obra.data?.nome ?? 'Obra',
                          style:
                              Tipografia.tituloTela.copyWith(color: c.grafite),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  [
                    CelulaCarimbo(
                      rotulo: 'Registros',
                      valor: '${entradas.length}',
                    ),
                    CelulaCarimbo(
                      rotulo: 'Último',
                      valor: ultimo == null ? '—' : Formatters.data(ultimo),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: Espaco.e24),
              if (entradas.isEmpty)
                const AvisoVazio(
                  icone: Icons.menu_book_outlined,
                  titulo: 'Diário vazio',
                  texto: 'Registre o que aconteceu no canteiro hoje: '
                      'atividades, equipe presente e condições do tempo. Dá '
                      'para ditar por voz ou deixar a IA ler a foto do '
                      'canteiro.',
                )
              else
                for (var i = 0; i < entradas.length; i++) ...[
                  if (i > 0) const SizedBox(height: Espaco.e12),
                  _CartaoDiario(entrada: entradas[i]),
                ],
            ],
          );
        },
      ),
      bottomNavigationBar: BarraDeAcao(
        principal: BotaoPrincipal(
          rotulo: 'Registrar dia',
          icone: Icons.add,
          grande: true,
          expandir: true,
          aoTocar: () => _novaEntrada(context),
        ),
      ),
    );
  }

  void _novaEntrada(BuildContext context) {
    unawaited(showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormDiario(obraId: widget.obraId),
    ));
  }
}

/// Ícone do clima (o texto vai junto: nunca só o ícone).
IconData _iconeDoClima(String clima) => switch (clima) {
      'Ensolarado' => Icons.wb_sunny_outlined,
      'Nublado' => Icons.cloud_outlined,
      'Chuvoso' => Icons.umbrella_outlined,
      'Chuva forte' => Icons.thunderstorm_outlined,
      _ => Icons.wb_sunny_outlined,
    };

class _CartaoDiario extends StatelessWidget {
  final DiarioEntradaModel entrada;

  const _CartaoDiario({required this.entrada});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Folha(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  Formatters.diaSemana(entrada.data),
                  style: Tipografia.subtitulo.copyWith(color: c.grafite),
                ),
              ),
              const SizedBox(width: Espaco.e8),
              Icon(_iconeDoClima(entrada.clima), size: 20, color: c.grafite),
              const SizedBox(width: Espaco.e4),
              Text(entrada.clima,
                  style: Tipografia.apoio.copyWith(color: c.grafite)),
            ],
          ),
          if (entrada.fase.isNotEmpty) ...[
            const SizedBox(height: Espaco.e4),
            Text(
              entrada.fase.toUpperCase(),
              style: Tipografia.rotulo.copyWith(color: c.marcaTexto),
            ),
          ],
          const SizedBox(height: Espaco.e8),
          Text(entrada.descricao,
              style: Tipografia.corpo.copyWith(color: c.grafite)),
          if (entrada.fotosUrls.isNotEmpty) ...[
            const SizedBox(height: Espaco.e12),
            if (entrada.fotosUrls.length == 1)
              ClipRRect(
                borderRadius: Raio.cantoPequeno,
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: ImagemObra(entrada.fotosUrls.first),
                ),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: entrada.fotosUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: Espaco.e8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: Raio.cantoPequeno,
                    child: SizedBox(
                      width: 160,
                      child: ImagemObra(entrada.fotosUrls[i]),
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: Espaco.e12),
          Divider(height: Traco.fino, thickness: Traco.fino, color: c.grade),
          const SizedBox(height: Espaco.e8),
          Row(
            children: [
              Icon(Icons.groups_outlined, size: 20, color: c.grafite2),
              const SizedBox(width: Espaco.e4),
              Text(
                '${entrada.numeroPessoas} no canteiro',
                style: Tipografia.apoio.copyWith(
                    color: c.grafite2, fontFeatures: Tipografia.tabular),
              ),
              const SizedBox(width: Espaco.e8),
              Expanded(
                child: Text(
                  'por ${entrada.registradoPorNome}',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tipografia.apoio.copyWith(color: c.grafite2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormDiario extends StatefulWidget {
  final String obraId;

  const _FormDiario({required this.obraId});

  @override
  State<_FormDiario> createState() => _FormDiarioState();
}

class _FormDiarioState extends State<_FormDiario> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoCtrl = TextEditingController();
  final _pessoasCtrl = TextEditingController(text: '1');
  String _clima = 'Ensolarado';

  /// O clima veio da fala ou do toque do usuário — a foto não sobrescreve.
  /// 'Ensolarado' é só o padrão do formulário, não uma escolha.
  bool _climaDefinido = false;
  String? _fase;
  DateTime _data = DateTime.now();
  final List<File> _fotos = [];
  String? _avisoIa;
  List<String> _materiaisVistos = const [];
  List<RotuloFoto> _rotulosVistos = const [];
  PaletaObra _paletaVista = const PaletaObra();
  bool _analisando = false;
  bool _salvando = false;

  final _voz = VozService();
  final _fotoIa = DiarioFotoService();

  /// Até 3 fotos por registro: o Firestore guarda a imagem embutida como
  /// data URI e o documento tem limite de 1 MB.
  static const int _maxFotos = 3;

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _pessoasCtrl.dispose();
    _fotoIa.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ Voz

  Future<void> _ditarODia() async {
    final relato = await mostrarPainelVozDiario(context, _voz);
    if (relato == null || !mounted) return;

    setState(() {
      _descricaoCtrl.text = relato.descricao;
      if (relato.clima != null) {
        _clima = relato.clima!;
        _climaDefinido = true;
      }
      if (relato.numeroPessoas != null) {
        _pessoasCtrl.text = relato.numeroPessoas!.toString();
      }
      if (relato.fase != null) _fase = relato.fase;
      if (relato.data != null) _data = relato.data!;
      _avisoIa = relato.temAlgo
          ? 'Registro montado a partir da sua fala — confira antes de salvar.'
          : 'Anotei o relato. Não identifiquei clima, equipe nem fase: '
              'confira os campos abaixo.';
    });
  }

  // ----------------------------------------------------------------- Foto

  Future<void> _analisarFoto() async {
    if (_fotos.length >= _maxFotos) {
      setState(() => _avisoIa = 'Máximo de $_maxFotos fotos por registro.');
      return;
    }

    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinhaLista(
              icone: Icons.photo_camera_outlined,
              titulo: 'Tirar foto do canteiro',
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

    final XFile? xfile;
    try {
      xfile = await ImagePicker().pickImage(
        source: origem,
        imageQuality: 85,
        maxWidth: 1600,
      );
    } catch (e) {
      // Câmera sem permissão ou indisponível: diz o que fazer, não o código
      // do erro.
      debugPrint('Diário: falha ao abrir a câmera: $e');
      if (mounted) setState(() => _avisoIa = MensagensErro.daCamera(e));
      return;
    }
    if (xfile == null || !mounted) return;
    final caminho = xfile.path;

    setState(() {
      _fotos.add(File(caminho));
      _analisando = true;
      _avisoIa = null;
    });

    try {
      final analise = await _fotoIa.analisar(caminho);
      if (!mounted) return;
      setState(() {
        _materiaisVistos = analise.materiais;
        _rotulosVistos = analise.rotulos;
        _paletaVista = analise.paleta;
        // Fase só é preenchida quando a evidência sustenta. Palpite fraco
        // vira aviso, não campo preenchido: corrigir o que a IA errou dá
        // mais trabalho do que escolher do zero.
        final faseConfiavel = analise.confiancaFase >= 0.5;
        if (analise.faseSugerida != null && _fase == null && faseConfiavel) {
          _fase = analise.faseSugerida;
        }
        // O céu da foto é palpite; o que você falou ou marcou, não.
        if (analise.climaSugerido != null && !_climaDefinido) {
          _clima = analise.climaSugerido!;
        }
        // A foto sugere o texto só quando o campo ainda está vazio — nunca
        // por cima do que a pessoa escreveu ou ditou.
        if (_descricaoCtrl.text.trim().isEmpty &&
            analise.descricaoSugerida.isNotEmpty) {
          _descricaoCtrl.text = analise.descricaoSugerida;
        }
        _avisoIa = _avisoDaFoto(analise, faseConfiavel);
      });
    } catch (e) {
      debugPrint('Diário: falha ao analisar a foto: $e');
      if (!mounted) return;
      // A foto já está anexada; só a leitura da IA falhou.
      setState(() => _avisoIa =
          '${MensagensErro.daAnalise(e, oQue: 'a foto')} A foto ficou '
              'anexada ao registro.');
    } finally {
      if (mounted) setState(() => _analisando = false);
    }
  }

  /// Diz o que a IA concluiu e o quanto ela está segura disso — um palpite
  /// anunciado como palpite é útil; anunciado como certeza, atrapalha.
  String _avisoDaFoto(AnaliseFotoDiario analise, bool faseConfiavel) {
    if (!analise.encontrouAlgo) {
      return 'Não reconheci a cena desta foto (ela ficou anexada mesmo '
          'assim). Fotos abertas do canteiro, com boa luz, funcionam '
          'melhor que fotos de detalhe.';
    }
    final fase = analise.faseSugerida;
    if (fase != null && faseConfiavel) {
      return 'Pela foto, a obra parece estar em $fase. Preenchi os campos '
          'abaixo — ajuste o que não bater com o dia.';
    }
    if (fase != null) {
      return 'A foto lembra $fase, mas com pouca certeza, então não '
          'preenchi a fase. Escolha você mesmo abaixo.';
    }
    return 'Reconheci o que aparece na foto, mas não dá para dizer a etapa '
        'da obra por ela. Preencha a fase abaixo.';
  }

  /// Rótulo do modelo próprio aparece com o nome da fase, para não ser
  /// confundido com os rótulos em inglês do modelo base.
  static String _nomeDoRotulo(String rotulo) {
    final fase = ModeloFases.faseDoRotulo(rotulo);
    return fase == null ? rotulo : 'Modelo da obra: $fase';
  }

  /// Mostra os rótulos crus do modelo. O classificador é de uso geral, não
  /// de construção: quando ele errar a fase, é aqui que dá para ver por quê.
  void _verOQueIaViu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final c = ctx.cores;
        return Padding(
          padding: EdgeInsets.only(
            left: Espaco.margem,
            right: Espaco.margem,
            top: Espaco.e8,
            bottom: MediaQuery.of(ctx).viewPadding.bottom + Espaco.e24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Rotulo('Foto do canteiro'),
              const SizedBox(height: Espaco.e4),
              Text('O que a IA viu na foto',
                  style: Tipografia.titulo.copyWith(color: c.grafite)),
              const SizedBox(height: Espaco.e8),
              Text(
                'A fase sai de duas leituras: os rótulos do modelo de visão '
                'e a composição de cores da própria foto. Se ela saiu '
                'errada, é aqui que dá para ver por quê.',
                style: Tipografia.apoio.copyWith(color: c.grafite2),
              ),
              const SizedBox(height: Espaco.e16),
              const LinhaCota(legenda: 'Cores da foto'),
              const SizedBox(height: Espaco.e8),
              Wrap(
                spacing: Espaco.e8,
                runSpacing: Espaco.e8,
                children: [
                  for (final (rotulo, fatia) in [
                    ('Terra', _paletaVista.terra),
                    ('Madeira', _paletaVista.madeira),
                    ('Tijolo', _paletaVista.tijolo),
                    ('Concreto', _paletaVista.concreto),
                    ('Parede clara', _paletaVista.claro),
                    ('Vegetação', _paletaVista.vegetacao),
                  ])
                    if (fatia >= 0.03)
                      Chip(
                        label: Text(
                          '$rotulo ${(fatia * 100).toStringAsFixed(0)}%',
                          style: Tipografia.apoio.copyWith(
                              color: c.grafite,
                              fontFeatures: Tipografia.tabular),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: Espaco.e16),
              const LinhaCota(legenda: 'Rótulos do modelo'),
              const SizedBox(height: Espaco.e8),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final r in _rotulosVistos)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: Espaco.e4),
                          child: ParComValor(
                            esquerda: SelectableText(_nomeDoRotulo(r.label),
                                style: Tipografia.corpo
                                    .copyWith(color: c.grafite)),
                            direita: Text(
                              '${(r.confianca * 100).toStringAsFixed(0)}%',
                              style: Tipografia.corpoForte.copyWith(
                                  color: c.grafite,
                                  fontFeatures: Tipografia.tabular),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------- Salvar

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      unawaited(Tato.erro());
      return;
    }
    setState(() => _salvando = true);

    final db = context.read<FirestoreService>();
    final usuario = context.read<AuthProvider>().usuario!;

    try {
      // Várias fotos dividem o mesmo documento do Firestore: com mais de
      // uma, cada foto entra menor para o registro caber no limite de 1 MB.
      final fotos = <String>[];
      var tamanhoTotal = 0;
      for (final foto in _fotos) {
        final uri = await ImagemService.comprimirParaDataUri(
          foto,
          ladoMaximo: _fotos.length > 1 ? 760 : 900,
          qualidade: _fotos.length > 1 ? 65 : 70,
        );
        tamanhoTotal += uri.length;
        fotos.add(uri);
      }
      if (tamanhoTotal > 850000) {
        if (!mounted) return;
        setState(() {
          _salvando = false;
          _avisoIa = 'As fotos ficaram grandes demais para um registro só. '
              'Remova uma delas e salve de novo.';
        });
        return;
      }

      await db.criarEntradaDiario(DiarioEntradaModel(
        id: '',
        obraId: widget.obraId,
        descricao: _descricaoCtrl.text.trim(),
        fase: _fase ?? '',
        numeroPessoas: int.tryParse(_pessoasCtrl.text) ?? 0,
        clima: _clima,
        fotosUrls: fotos,
        registradoPorId: usuario.id,
        registradoPorNome: usuario.nome,
        data: _data,
        criadoEm: DateTime.now(),
      ));
      if (!mounted) return;
      unawaited(Tato.confirmar());
      mostrarAviso(context, 'Dia registrado no diário.');
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Diário: falha ao salvar o registro: $e');
      if (!mounted) return;
      setState(() => _salvando = false);
      unawaited(Tato.erro());
      mostrarAviso(context, MensagensErro.aoSalvar(e));
    }
  }

  // ------------------------------------------------------------------- UI

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

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final textoData = Formatters.data(_data);
    return Padding(
      padding: EdgeInsets.only(
        left: Espaco.margem,
        right: Espaco.margem,
        top: Espaco.e8,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            Espaco.e16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Rotulo('Diário de obra'),
              const SizedBox(height: Espaco.e4),
              Text('Registro do dia',
                  style: Tipografia.titulo.copyWith(color: c.grafite)),
              const SizedBox(height: Espaco.e16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: BotaoIa(
                        icone: Icons.mic_none,
                        rotulo: 'Ditar o dia',
                        descricao: 'Conte como foi',
                        onTap: _analisando ? null : _ditarODia,
                      ),
                    ),
                    const SizedBox(width: Espaco.entreAlvos),
                    Expanded(
                      child: BotaoIa(
                        icone: Icons.photo_camera_outlined,
                        rotulo: 'Foto do canteiro',
                        descricao: 'A IA lê a cena',
                        onTap: _analisando ? null : _analisarFoto,
                      ),
                    ),
                  ],
                ),
              ),
              if (_analisando) ...[
                const SizedBox(height: Espaco.e16),
                Semantics(
                  liveRegion: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const IndicadorCarregando(),
                      const SizedBox(width: Espaco.e12),
                      Text('Analisando a foto…',
                          style: Tipografia.corpo.copyWith(color: c.grafite)),
                    ],
                  ),
                ),
              ],
              if (_avisoIa != null) ...[
                const SizedBox(height: Espaco.e16),
                AvisoIa(mensagem: _avisoIa!),
              ],
              if (_rotulosVistos.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _verOQueIaViu,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Ver o que a IA viu na foto'),
                  ),
                ),
              if (_materiaisVistos.isNotEmpty) ...[
                const SizedBox(height: Espaco.e12),
                const Rotulo('Material visto na foto'),
                const SizedBox(height: Espaco.e8),
                Wrap(
                  spacing: Espaco.e8,
                  runSpacing: Espaco.e8,
                  children: [
                    for (final material in _materiaisVistos)
                      Chip(
                        avatar: Icon(Icons.visibility_outlined,
                            size: 18, color: c.grafite),
                        label: Text(material),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: Espaco.e24),
              const LinhaCota(legenda: 'O dia'),
              const SizedBox(height: Espaco.e16),
              TextFormField(
                controller: _descricaoCtrl,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'O que foi feito hoje?',
                  hintText: 'Ex.: Concluída a concretagem da laje do 1º andar',
                  alignLabelWithHint: true,
                ),
                validator: (v) => Validators.obrigatorio(v, 'A descrição'),
              ),
              const SizedBox(height: Espaco.e16),
              DropdownButtonFormField<String>(
                initialValue: _fase,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Fase da obra (opcional)'),
                items: [
                  for (final f in AppConstants.fasesPadrao)
                    DropdownMenuItem(value: f, child: Text(f)),
                ],
                onChanged: (v) => setState(() => _fase = v),
              ),
              const SizedBox(height: Espaco.e16),
              TextFormField(
                controller: _pessoasCtrl,
                keyboardType: TextInputType.number,
                style: Tipografia.corpo.copyWith(
                    color: c.grafite, fontFeatures: Tipografia.tabular),
                decoration: const InputDecoration(
                    labelText: 'Pessoas no canteiro hoje'),
                validator: Validators.numero,
              ),
              const SizedBox(height: Espaco.e16),
              AreaPressionavel(
                aoTocar: () => unawaited(_escolherData()),
                escala: 1,
                vibrar: true,
                rotuloSemantico: 'Dia do registro: $textoData',
                dicaSemantica: 'Abre o calendário para trocar a data',
                construtor: (context, e) => InputDecorator(
                  isFocused: e.focado || e.pressionado,
                  decoration: const InputDecoration(
                    labelText: 'Dia do registro',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(textoData,
                      style: Tipografia.corpo.copyWith(
                          color: c.grafite, fontFeatures: Tipografia.tabular)),
                ),
              ),
              const SizedBox(height: Espaco.e24),
              SeletorGrande<String>(
                rotulo: 'Clima',
                opcoes: [
                  for (final clima in AppConstants.climas)
                    OpcaoSeletor(
                        valor: clima,
                        rotulo: clima,
                        icone: _iconeDoClima(clima)),
                ],
                selecionado: _clima,
                aoMudar: (v) => setState(() {
                  _clima = v;
                  _climaDefinido = true;
                }),
              ),
              const SizedBox(height: Espaco.e24),
              if (_fotos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: Espaco.e12),
                  child: SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _fotos.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: Espaco.e8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: Raio.cantoPequeno,
                        child: Stack(
                          children: [
                            Image.file(_fotos[i],
                                height: 120, width: 160, fit: BoxFit.cover),
                            Positioned(
                              top: Espaco.e4,
                              right: Espaco.e4,
                              child: IconButton.filled(
                                tooltip: 'Tirar a foto',
                                style: IconButton.styleFrom(
                                  backgroundColor: c.grafite,
                                  foregroundColor: c.sobreGrafite,
                                  minimumSize:
                                      const Size(Alvo.minimo, Alvo.minimo),
                                ),
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _fotos.removeAt(i)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              BotaoContorno(
                rotulo: _fotos.isEmpty
                    ? 'Anexar foto'
                    : 'Anexar outra foto (${_fotos.length}/$_maxFotos)',
                icone: Icons.add_a_photo_outlined,
                expandir: true,
                aoTocar: _analisando || _fotos.length >= _maxFotos
                    ? null
                    : _analisarFoto,
              ),
              const SizedBox(height: Espaco.entreAlvos),
              BotaoPrincipal(
                rotulo: 'Salvar registro',
                icone: Icons.check,
                grande: true,
                expandir: true,
                carregando: _salvando,
                aoTocar: _salvando ? null : () => unawaited(_salvar()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
