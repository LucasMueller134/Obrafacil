import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/validators.dart';

/// Os fornecedores do dono: entram sozinhos pelas notas e lançamentos, ou
/// à mão. Tocar edita.
class FornecedoresScreen extends StatelessWidget {
  const FornecedoresScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const TemaPrancheta(child: _Fornecedores());
}

class _Fornecedores extends StatefulWidget {
  const _Fornecedores();

  @override
  State<_Fornecedores> createState() => _FornecedoresState();
}

class _FornecedoresState extends State<_Fornecedores> {
  Stream<List<FornecedorModel>>? _stream;
  String? _donoDaStream;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final usuario = context.watch<AuthProvider>().usuario;
    if (usuario == null) return const SizedBox.shrink();
    if (_donoDaStream != usuario.id) {
      _donoDaStream = usuario.id;
      _stream = context.read<FirestoreService>().fornecedores(usuario.id);
    }

    return Scaffold(
      appBar: AppBar(),
      body: StreamBuilder<List<FornecedorModel>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(Espaco.margem),
              children: const [
                EsqueletoFolha(
                    linhas: 4, rotuloSemantico: 'Abrindo os fornecedores'),
              ],
            );
          }
          final fornecedores = snapshot.data ?? const <FornecedorModel>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e32),
            children: [
              const Rotulo('Cadastro'),
              const SizedBox(height: Espaco.e4),
              Semantics(
                header: true,
                child: Text('Fornecedores',
                    style: Tipografia.tituloTela.copyWith(color: c.grafite)),
              ),
              const SizedBox(height: Espaco.e8),
              Text(
                'Entram sozinhos quando aparecem numa nota ou num '
                'lançamento. Toque para editar.',
                style: Tipografia.corpo.copyWith(color: c.grafite2),
              ),
              const SizedBox(height: Espaco.e24),
              if (fornecedores.isEmpty)
                const AvisoVazio(
                  icone: Icons.storefront_outlined,
                  titulo: 'Nenhum fornecedor',
                  texto: 'Fornecedores são cadastrados automaticamente quando '
                      'aparecem em notas fiscais e lançamentos, ou adicione '
                      'à mão.',
                )
              else ...[
                LinhaCota(
                    legenda: fornecedores.length == 1
                        ? '1 fornecedor'
                        : '${fornecedores.length} fornecedores'),
                const SizedBox(height: Espaco.e16),
                Folha(
                  preenchimento: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < fornecedores.length; i++)
                        _LinhaFornecedor(
                          fornecedor: fornecedores[i],
                          divisoria: i < fornecedores.length - 1,
                          aoTocar: () => _abrirFormulario(context, usuario.id,
                              fornecedor: fornecedores[i]),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: BarraDeAcao(
        principal: BotaoPrincipal(
          rotulo: 'Adicionar fornecedor',
          icone: Icons.add,
          grande: true,
          expandir: true,
          aoTocar: () => _abrirFormulario(context, usuario.id),
        ),
      ),
    );
  }

  void _abrirFormulario(BuildContext context, String donoId,
      {FornecedorModel? fornecedor}) {
    unawaited(showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormFornecedor(donoId: donoId, fornecedor: fornecedor),
    ));
  }
}

class _LinhaFornecedor extends StatelessWidget {
  const _LinhaFornecedor({
    required this.fornecedor,
    required this.divisoria,
    required this.aoTocar,
  });

  final FornecedorModel fornecedor;
  final bool divisoria;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final f = fornecedor;
    final apoio = [
      if (f.telefone != null && f.telefone!.isNotEmpty) f.telefone!,
      if (f.cnpj != null && f.cnpj!.isNotEmpty) 'CNPJ ${f.cnpj}',
      if (f.email != null && f.email!.isNotEmpty) f.email!,
    ].join(' · ');
    return LinhaLista(
      icone: Icons.storefront_outlined,
      titulo: f.nome,
      apoio: apoio.isEmpty ? 'Sem telefone nem CNPJ' : apoio,
      margemHorizontal: Espaco.e12,
      divisoria: divisoria,
      seta: true,
      aoTocar: aoTocar,
    );
  }
}

class _FormFornecedor extends StatefulWidget {
  final String donoId;
  final FornecedorModel? fornecedor;

  const _FormFornecedor({required this.donoId, this.fornecedor});

  @override
  State<_FormFornecedor> createState() => _FormFornecedorState();
}

class _FormFornecedorState extends State<_FormFornecedor> {
  final _formKey = GlobalKey<FormState>();
  late final _nomeCtrl =
      TextEditingController(text: widget.fornecedor?.nome ?? '');
  late final _telefoneCtrl =
      TextEditingController(text: widget.fornecedor?.telefone ?? '');
  late final _emailCtrl =
      TextEditingController(text: widget.fornecedor?.email ?? '');
  late final _cnpjCtrl =
      TextEditingController(text: widget.fornecedor?.cnpj ?? '');
  late final _obsCtrl =
      TextEditingController(text: widget.fornecedor?.observacoes ?? '');

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    _cnpjCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      unawaited(Tato.erro());
      return;
    }
    final db = context.read<FirestoreService>();
    await db.salvarFornecedor(FornecedorModel(
      id: widget.fornecedor?.id ?? '',
      donoId: widget.donoId,
      nome: _nomeCtrl.text.trim(),
      telefone:
          _telefoneCtrl.text.trim().isEmpty ? null : _telefoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      cnpj: _cnpjCtrl.text.trim().isEmpty ? null : _cnpjCtrl.text.trim(),
      observacoes: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      criadoEm: widget.fornecedor?.criadoEm ?? DateTime.now(),
    ));
    unawaited(Tato.confirmar());
    if (mounted) Navigator.pop(context);
  }

  /// Exclui na hora, com desfazer (grava o mesmo fornecedor de volta).
  Future<void> _excluir() async {
    final db = context.read<FirestoreService>();
    final f = widget.fornecedor!;
    await db.excluirFornecedor(f.id);
    unawaited(Tato.confirmar());
    if (!mounted) return;
    mostrarAviso(context, '${f.nome} saiu dos fornecedores.',
        aoDesfazer: () => unawaited(db.salvarFornecedor(f)));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
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
              const Rotulo('Fornecedores'),
              const SizedBox(height: Espaco.e4),
              Text(
                widget.fornecedor == null
                    ? 'Novo fornecedor'
                    : 'Editar fornecedor',
                style: Tipografia.titulo.copyWith(color: c.grafite),
              ),
              const SizedBox(height: Espaco.e16),
              TextFormField(
                controller: _nomeCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => Validators.obrigatorio(v, 'O nome'),
              ),
              const SizedBox(height: Espaco.e16),
              TextFormField(
                controller: _telefoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration:
                    const InputDecoration(labelText: 'Telefone (opcional)'),
              ),
              const SizedBox(height: Espaco.e16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration:
                    const InputDecoration(labelText: 'E-mail (opcional)'),
              ),
              const SizedBox(height: Espaco.e16),
              TextFormField(
                controller: _cnpjCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                style: Tipografia.corpo.copyWith(
                    color: c.grafite, fontFeatures: Tipografia.tabular),
                decoration: const InputDecoration(labelText: 'CNPJ (opcional)'),
              ),
              const SizedBox(height: Espaco.e16),
              TextFormField(
                controller: _obsCtrl,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Observações (opcional)',
                    alignLabelWithHint: true),
              ),
              const SizedBox(height: Espaco.e24),
              BotaoPrincipal(
                rotulo: 'Salvar',
                icone: Icons.check,
                grande: true,
                expandir: true,
                aoTocar: () => unawaited(_salvar()),
              ),
              if (widget.fornecedor != null) ...[
                const SizedBox(height: Espaco.e8),
                TextButton.icon(
                  onPressed: () => unawaited(_excluir()),
                  style: TextButton.styleFrom(foregroundColor: c.revisao),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir fornecedor'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
