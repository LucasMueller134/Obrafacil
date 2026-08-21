import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/cores_foto.dart';
import '../../services/ia/diario_foto_service.dart';
import '../../services/ia/voz_service.dart';
import '../../services/imagem_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/animacoes.dart';
import '../../widgets/botao_ia.dart';
import '../../widgets/carregando_obra.dart';
import '../../widgets/estado_vazio.dart';
import '../../widgets/ilustracoes.dart';
import '../../widgets/imagem_obra.dart';
import '../../widgets/painel_voz.dart';

class DiarioScreen extends StatelessWidget {
  final String obraId;

  const DiarioScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Diário de obra')),
      body: StreamBuilder<List<DiarioEntradaModel>>(
        stream: db.diario(obraId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CarregandoObra(mensagem: 'Abrindo o diário…');
          }
          final entradas = snapshot.data ?? const <DiarioEntradaModel>[];
          if (entradas.isEmpty) {
            return EstadoVazio(
              icone: Icons.menu_book,
              ilustracao: const IlustracaoPrancheta(),
              titulo: 'Diário vazio',
              mensagem:
                  'Registre o que aconteceu no canteiro hoje: atividades, '
                  'equipe presente e condições do tempo. Dá para ditar por '
                  'voz ou deixar a IA ler a foto do canteiro.',
              rotuloAcao: 'Registrar dia',
              onAcao: () => _novaEntrada(context),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.of(context).padding.bottom + 96),
            itemCount: entradas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) =>
                _CartaoDiario(entrada: entradas[i]).aparecer(i),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _novaEntrada(context),
        icon: const Icon(Icons.add),
        label: const Text('Registrar dia'),
      ),
    );
  }

  void _novaEntrada(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormDiario(obraId: obraId),
    );
  }
}

class _CartaoDiario extends StatelessWidget {
  final DiarioEntradaModel entrada;

  const _CartaoDiario({required this.entrada});

  IconData get _iconeClima => switch (entrada.clima) {
        'Ensolarado' => Icons.wb_sunny,
        'Nublado' => Icons.cloud,
        'Chuvoso' => Icons.umbrella,
        'Chuva forte' => Icons.thunderstorm,
        _ => Icons.wb_sunny,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Formatters.diaSemana(entrada.data),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(_iconeClima, size: 18, color: AppColors.amareloCapacete),
                const SizedBox(width: 4),
                Text(
                  entrada.clima,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textoSecundario),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (entrada.fase.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.laranja.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entrada.fase,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.laranja,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            Text(entrada.descricao,
                style: Theme.of(context).textTheme.bodyMedium),
            if (entrada.fotosUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              if (entrada.fotosUrls.length == 1)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: ImagemObra(entrada.fotosUrls.first),
                  ),
                )
              else
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: entrada.fotosUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 150,
                        child: ImagemObra(entrada.fotosUrls[i]),
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.groups,
                    size: 15, color: AppColors.textoSecundario),
                const SizedBox(width: 4),
                Text(
                  '${entrada.numeroPessoas} no canteiro',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textoSecundario),
                ),
                const Spacer(),
                Text(
                  'por ${entrada.registradoPorNome}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textoDesabilitado),
                ),
              ],
            ),
          ],
        ),
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
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Tirar foto do canteiro'),
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

    final xfile = await ImagePicker().pickImage(
      source: origem,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (xfile == null || !mounted) return;

    setState(() {
      _fotos.add(File(xfile.path));
      _analisando = true;
      _avisoIa = null;
    });

    try {
      final analise = await _fotoIa.analisar(xfile.path);
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
      if (!mounted) return;
      setState(() => _avisoIa = 'Erro ao analisar a foto: $e');
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

  /// Mostra os rótulos crus do modelo. O classificador é de uso geral, não
  /// de construção: quando ele errar a fase, é aqui que dá para ver por quê.
  void _verOQueIaViu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewPadding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('O que a IA viu na foto',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'A fase sai de duas leituras: os rótulos do modelo de visão '
              'e a composição de cores da própria foto. Se ela saiu '
              'errada, é aqui que dá para ver por quê.',
              style: Theme.of(ctx)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textoSecundario),
            ),
            const SizedBox(height: 12),
            Text('Cores da foto',
                style: Theme.of(ctx)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (rotulo, fatia) in [
                  ('Terra', _paletaVista.terra),
                  ('Tijolo', _paletaVista.tijolo),
                  ('Concreto', _paletaVista.concreto),
                  ('Parede clara', _paletaVista.claro),
                  ('Vegetação', _paletaVista.vegetacao),
                ])
                  if (fatia >= 0.03)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '$rotulo ${(fatia * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Rótulos do modelo',
                style: Theme.of(ctx)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.45),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final r in _rotulosVistos)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: SelectableText(r.label)),
                            Text(
                              '${(r.confianca * 100).toStringAsFixed(0)}%',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.laranja),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- Salvar

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
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
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $e')));
    }
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Registro do dia',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: BotaoIa(
                      icone: Icons.mic,
                      rotulo: 'Ditar o dia',
                      descricao: 'Conte como foi',
                      onTap: _analisando ? null : _ditarODia,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BotaoIa(
                      icone: Icons.photo_camera,
                      rotulo: 'Foto do canteiro',
                      descricao: 'A IA lê a cena',
                      onTap: _analisando ? null : _analisarFoto,
                    ),
                  ),
                ],
              ),
              if (_analisando) ...[
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(width: 10),
                    Text('Analisando a foto…'),
                  ],
                ),
              ],
              if (_avisoIa != null) ...[
                const SizedBox(height: 16),
                AvisoIa(mensagem: _avisoIa!),
              ],
              if (_rotulosVistos.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _verOQueIaViu,
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Ver o que a IA viu na foto'),
                  ),
                ),
              if (_materiaisVistos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Material visto na foto',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final material in _materiaisVistos)
                      Chip(
                        avatar: const Icon(Icons.visibility,
                            size: 16, color: AppColors.laranja),
                        label: Text(material),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              TextFormField(
                controller: _descricaoCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'O que foi feito hoje?',
                  hintText: 'Ex.: Concluída a concretagem da laje do 1º andar',
                ),
                validator: (v) => Validators.obrigatorio(v, 'A descrição'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _fase,
                decoration:
                    const InputDecoration(labelText: 'Fase da obra (opcional)'),
                items: [
                  for (final f in AppConstants.fasesPadrao)
                    DropdownMenuItem(value: f, child: Text(f)),
                ],
                onChanged: (v) => setState(() => _fase = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pessoasCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Pessoas no canteiro hoje'),
                validator: Validators.numero,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final escolhida = await showDatePicker(
                    context: context,
                    initialDate: _data,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    locale: const Locale('pt', 'BR'),
                  );
                  if (escolhida != null) setState(() => _data = escolhida);
                },
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Dia do registro',
                    prefixIcon: Icon(Icons.calendar_today, size: 20),
                  ),
                  child: Text(Formatters.data(_data)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Clima', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in AppConstants.climas)
                    ChoiceChip(
                      label: Text(c),
                      selected: _clima == c,
                      onSelected: (_) => setState(() {
                        _clima = c;
                        _climaDefinido = true;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_fotos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _fotos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Image.file(_fotos[i],
                                height: 110, width: 150, fit: BoxFit.cover),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton.filled(
                                style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                    minimumSize: const Size(32, 32)),
                                icon: const Icon(Icons.close, size: 16),
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
              OutlinedButton.icon(
                onPressed: _analisando ? null : _analisarFoto,
                icon: const Icon(Icons.add_a_photo),
                label: Text(_fotos.isEmpty
                    ? 'Anexar foto'
                    : 'Anexar outra foto (${_fotos.length}/$_maxFotos)'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Salvar registro'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
