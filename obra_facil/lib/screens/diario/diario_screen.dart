import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/imagem_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/estado_vazio.dart';
import '../../widgets/imagem_obra.dart';

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
            return const Center(child: CircularProgressIndicator());
          }
          final entradas = snapshot.data ?? const <DiarioEntradaModel>[];
          if (entradas.isEmpty) {
            return EstadoVazio(
              icone: Icons.menu_book,
              titulo: 'Diário vazio',
              mensagem:
                  'Registre o que aconteceu no canteiro hoje: atividades, '
                  'equipe presente e condições do tempo.',
              rotuloAcao: 'Registrar dia',
              onAcao: () => _novaEntrada(context),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.of(context).padding.bottom + 96),
            itemCount: entradas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _CartaoDiario(entrada: entradas[i]),
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
                Icon(_iconeClima,
                    size: 18, color: AppColors.amareloCapacete),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: ImagemObra(entrada.fotosUrls.first),
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
  String? _fase;
  File? _foto;
  bool _salvando = false;

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _pessoasCtrl.dispose();
    super.dispose();
  }

  Future<void> _tirarFoto() async {
    final xfile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (xfile != null && mounted) setState(() => _foto = File(xfile.path));
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    final db = context.read<FirestoreService>();
    final usuario = context.read<AuthProvider>().usuario!;

    final fotos = <String>[];
    if (_foto != null) {
      fotos.add(await ImagemService.comprimirParaDataUri(_foto!));
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
      data: DateTime.now(),
      criadoEm: DateTime.now(),
    ));
    if (mounted) Navigator.pop(context);
  }

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
              Text('Clima', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in AppConstants.climas)
                    ChoiceChip(
                      label: Text(c),
                      selected: _clima == c,
                      onSelected: (_) => setState(() => _clima = c),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_foto != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_foto!,
                        height: 140, width: double.infinity, fit: BoxFit.cover),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _tirarFoto,
                icon: const Icon(Icons.photo_camera),
                label: Text(_foto == null ? 'Anexar foto' : 'Trocar foto'),
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
