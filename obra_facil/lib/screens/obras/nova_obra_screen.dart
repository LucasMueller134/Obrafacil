import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/cep_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';

class NovaObraScreen extends StatefulWidget {
  const NovaObraScreen({super.key});

  @override
  State<NovaObraScreen> createState() => _NovaObraScreenState();
}

class _NovaObraScreenState extends State<NovaObraScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _clienteCtrl = TextEditingController();
  final _orcamentoCtrl = TextEditingController();
  DateTime _dataInicio = DateTime.now();
  DateTime _previsaoTermino = DateTime.now().add(const Duration(days: 180));
  bool _criarCronograma = true;
  bool _salvando = false;
  bool _consultandoCep = false;
  ResultadoCep? _resultadoCep;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cepCtrl.dispose();
    _enderecoCtrl.dispose();
    _numeroCtrl.dispose();
    _clienteCtrl.dispose();
    _orcamentoCtrl.dispose();
    super.dispose();
  }

  /// Consulta os Correios e preenche o endereço com o que voltar.
  Future<void> _consultarCep() async {
    setState(() {
      _consultandoCep = true;
      _resultadoCep = null;
    });
    final resultado = await CepService.consultar(_cepCtrl.text);
    if (!mounted) return;
    setState(() {
      _consultandoCep = false;
      _resultadoCep = resultado;
      final endereco = resultado.endereco;
      if (endereco != null) {
        _cepCtrl.text = endereco.cepFormatado;
        // Não apaga o que o usuário já escreveu à mão.
        if (_enderecoCtrl.text.trim().isEmpty) {
          _enderecoCtrl.text = endereco.linha;
        }
      }
    });
  }

  /// Junta rua, número e CEP numa linha só — é assim que a obra guarda o
  /// endereço, e é o que o cliente vê no acompanhamento.
  String _enderecoCompleto() {
    final base = _enderecoCtrl.text.trim();
    final numero = _numeroCtrl.text.trim();
    final cep = CepService.formatar(_cepCtrl.text);
    final rua = numero.isEmpty ? base : '$base, $numero';
    return CepService.normalizar(_cepCtrl.text) == null
        ? rua
        : '$rua — CEP $cep';
  }

  /// CEP existente é exigido; sem internet, o formato basta — o cadastro
  /// não pode ficar refém de sinal no canteiro.
  String? _validarCep(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o CEP';
    if (CepService.normalizar(v) == null) return 'CEP precisa ter 8 números';
    if (_resultadoCep?.situacao == SituacaoCep.inexistente) {
      return 'Este CEP não existe — confira o número';
    }
    return null;
  }

  Future<void> _escolherData({required bool inicio}) async {
    final atual = inicio ? _dataInicio : _previsaoTermino;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('pt', 'BR'),
    );
    if (escolhida == null) return;
    setState(() {
      if (inicio) {
        _dataInicio = escolhida;
        if (!_previsaoTermino.isAfter(_dataInicio)) {
          _previsaoTermino = _dataInicio.add(const Duration(days: 30));
        }
      } else {
        _previsaoTermino = escolhida;
      }
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_previsaoTermino.isAfter(_dataInicio)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A previsão de término deve ser após o início.')));
      return;
    }
    // Quem não tocou no botão de conferir tem o CEP conferido agora: é
    // aqui que um endereço inventado é barrado.
    if (_resultadoCep == null) {
      await _consultarCep();
      if (!mounted) return;
      if (_resultadoCep?.situacao == SituacaoCep.inexistente) {
        _formKey.currentState!.validate();
        return;
      }
    }
    setState(() => _salvando = true);

    final usuario = context.read<AuthProvider>().usuario!;
    final db = context.read<FirestoreService>();

    final obra = ObraModel(
      id: '',
      nome: _nomeCtrl.text.trim(),
      endereco: _enderecoCompleto(),
      cliente: _clienteCtrl.text.trim().isEmpty
          ? null
          : _clienteCtrl.text.trim(),
      orcamento: Formatters.parseValor(_orcamentoCtrl.text)!,
      dataInicio: _dataInicio,
      previsaoTermino: _previsaoTermino,
      donoId: usuario.id,
      codigoConvite: FirestoreService.gerarCodigoConvite(),
      criadoEm: DateTime.now(),
    );

    try {
      final obraId = await db.criarObra(obra);
      if (_criarCronograma) {
        await _gerarCronogramaPadrao(db, obraId);
      }
      if (!mounted) return;
      context.go('/obras/$obraId');
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $e')));
    }
  }

  /// Distribui as fases padrão uniformemente entre o início e o fim da obra.
  Future<void> _gerarCronogramaPadrao(
      FirestoreService db, String obraId) async {
    final fases = AppConstants.fasesPadrao;
    final duracaoTotal = _previsaoTermino.difference(_dataInicio).inDays;
    final diasPorFase = (duracaoTotal / fases.length).floor().clamp(1, 9999);

    for (var i = 0; i < fases.length; i++) {
      final inicio = _dataInicio.add(Duration(days: diasPorFase * i));
      final fim = i == fases.length - 1
          ? _previsaoTermino
          : _dataInicio.add(Duration(days: diasPorFase * (i + 1)));
      await db.salvarFase(CronogramaFaseModel(
        id: '',
        obraId: obraId,
        nome: fases[i],
        ordem: i,
        dataInicio: inicio,
        dataFim: fim,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova obra')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nomeCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nome da obra',
                    hintText: 'Ex.: Casa do Sr. João',
                    prefixIcon: Icon(Icons.apartment),
                  ),
                  validator: (v) => Validators.obrigatorio(v, 'O nome'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cepCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 9,
                  onChanged: (_) => setState(() => _resultadoCep = null),
                  decoration: InputDecoration(
                    labelText: 'CEP',
                    hintText: '00000-000',
                    counterText: '',
                    prefixIcon: const Icon(Icons.markunread_mailbox_outlined),
                    suffixIcon: _consultandoCep
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          )
                        : IconButton(
                            tooltip: 'Conferir CEP',
                            icon: const Icon(Icons.search),
                            onPressed: _consultarCep,
                          ),
                  ),
                  validator: _validarCep,
                ),
                if (_resultadoCep != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _resultadoCep!.valido
                            ? Icons.check_circle
                            : _resultadoCep!.situacao == SituacaoCep.semResposta
                                ? Icons.cloud_off
                                : Icons.error_outline,
                        size: 16,
                        color: _resultadoCep!.valido
                            ? AppColors.sucesso
                            : _resultadoCep!.situacao == SituacaoCep.semResposta
                                ? AppColors.textoSecundario
                                : AppColors.erro,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _resultadoCep!.mensagem,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: _resultadoCep!.valido
                                    ? AppColors.sucesso
                                    : AppColors.textoSecundario,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _enderecoCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Endereço',
                    hintText: 'Conferido o CEP, preenche sozinho',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  validator: (v) => Validators.obrigatorio(v, 'O endereço'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _numeroCtrl,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'Número e complemento (opcional)',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _clienteCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Cliente (opcional)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _orcamentoCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Orçamento total (R\$)',
                    hintText: 'Ex.: 250.000,00',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: Validators.valor,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _CampoData(
                        rotulo: 'Início',
                        data: _dataInicio,
                        onTap: () => _escolherData(inicio: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CampoData(
                        rotulo: 'Previsão de término',
                        data: _previsaoTermino,
                        onTap: () => _escolherData(inicio: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _criarCronograma,
                  onChanged: (v) => setState(() => _criarCronograma = v),
                  title: const Text('Gerar cronograma com fases padrão'),
                  subtitle: Text(
                    'Cria ${AppConstants.fasesPadrao.length} fases (fundação, '
                    'estrutura, alvenaria...) distribuídas no período da obra',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textoSecundario),
                  ),
                  activeTrackColor: AppColors.laranja,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Criar obra'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CampoData extends StatelessWidget {
  final String rotulo;
  final DateTime data;
  final VoidCallback onTap;

  const _CampoData({
    required this.rotulo,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: rotulo,
          prefixIcon: const Icon(Icons.calendar_today, size: 20),
        ),
        child: Text(Formatters.data(data)),
      ),
    );
  }
}
