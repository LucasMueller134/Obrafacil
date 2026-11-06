import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../design/design.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/cep_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../planta/modelo_planta.dart';

/// De onde vem a planta da obra nova: um modelo pronto ou o projeto real
/// (enviado depois, na tela da planta).
enum _Construcao { casa, geminado, predio, projeto }

/// Cadastrar uma obra: nome e cliente, endereço (com o CEP conferido nos
/// Correios), orçamento, prazo e o cronograma com as fases padrão.
class NovaObraScreen extends StatelessWidget {
  const NovaObraScreen({super.key});

  @override
  Widget build(BuildContext context) => const TemaPrancheta(child: _NovaObra());
}

class _NovaObra extends StatefulWidget {
  const _NovaObra();

  @override
  State<_NovaObra> createState() => _NovaObraScreenState();
}

class _NovaObraScreenState extends State<_NovaObra> {
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
  _Construcao _construcao = _Construcao.casa;
  PedidoModelo _pedido = pedidoInicial(TipoModelo.casa);

  /// O modelo escolhido (nulo: projeto real).
  PedidoModelo? get _modelo =>
      _construcao == _Construcao.projeto ? null : _pedido;

  void _escolherConstrucao(_Construcao c) {
    setState(() {
      _construcao = c;
      final tipo = switch (c) {
        _Construcao.geminado => TipoModelo.geminado,
        _Construcao.predio => TipoModelo.predio,
        _ => TipoModelo.casa,
      };
      if (c != _Construcao.projeto && _pedido.tipo != tipo) {
        _pedido = pedidoInicial(tipo);
      }
    });
  }

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
    if (!_formKey.currentState!.validate()) {
      unawaited(Tato.erro());
      return;
    }
    if (!_previsaoTermino.isAfter(_dataInicio)) {
      unawaited(Tato.erro());
      mostrarAviso(context, 'A previsão de término deve ser após o início.');
      return;
    }
    final problemaDoModelo = _modelo?.problema;
    if (problemaDoModelo != null) {
      unawaited(Tato.erro());
      mostrarAviso(context, 'A construção: $problemaDoModelo');
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
      cliente:
          _clienteCtrl.text.trim().isEmpty ? null : _clienteCtrl.text.trim(),
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
      // A planta do modelo: a maquete e o "por dentro" já nascem com ela.
      final modelo = _modelo;
      if (modelo != null) {
        await db.salvarPlanta(obraId, ModelosPlanta.montar(modelo));
      }
      if (!mounted) return;
      unawaited(Tato.confirmar());
      context.go('/obras/$obraId');
      // Projeto real: abre a planta, que é onde ele é enviado.
      if (modelo == null) unawaited(context.push('/obras/$obraId/planta'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      unawaited(Tato.erro());
      mostrarAviso(context, 'Não foi possível salvar: $e');
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
    final c = context.cores;
    final cep = _resultadoCep;
    final dias = _previsaoTermino.difference(_dataInicio).inDays;
    final estiloValor = Tipografia.valorHeroi.copyWith(
      fontSize: 32,
      height: 1.1,
      color: c.grafite,
    );
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Rotulo('Obras'),
                const SizedBox(height: Espaco.e4),
                Semantics(
                  header: true,
                  child: Text('Nova obra',
                      style: Tipografia.tituloTela.copyWith(color: c.grafite)),
                ),
                const SizedBox(height: Espaco.e24),
                const LinhaCota(legenda: 'A obra'),
                const SizedBox(height: Espaco.e16),
                TextFormField(
                  controller: _nomeCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nome da obra',
                    hintText: 'Ex.: Casa do Sr. João',
                  ),
                  validator: (v) => Validators.obrigatorio(v, 'O nome'),
                ),
                const SizedBox(height: Espaco.e16),
                TextFormField(
                  controller: _clienteCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Cliente (opcional)',
                    helperText: 'Quem vai morar ou pagar a obra.',
                  ),
                ),
                const SizedBox(height: Espaco.e24),
                const LinhaCota(legenda: 'Endereço'),
                const SizedBox(height: Espaco.e16),
                TextFormField(
                  controller: _cepCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 9,
                  onChanged: (_) => setState(() => _resultadoCep = null),
                  onFieldSubmitted: (_) => unawaited(_consultarCep()),
                  style: Tipografia.corpo.copyWith(
                      color: c.grafite, fontFeatures: Tipografia.tabular),
                  decoration: InputDecoration(
                    labelText: 'CEP',
                    hintText: '00000-000',
                    counterText: '',
                    suffixIcon: _consultandoCep
                        ? const Padding(
                            padding: EdgeInsets.all(Espaco.e12),
                            child: IndicadorCarregando(tamanho: 24),
                          )
                        : IconButton(
                            tooltip: 'Conferir CEP',
                            icon: const Icon(Icons.search),
                            onPressed: _consultarCep,
                          ),
                  ),
                  validator: _validarCep,
                ),
                if (cep != null) ...[
                  const SizedBox(height: Espaco.e8),
                  _ResultadoDoCep(resultado: cep),
                ],
                const SizedBox(height: Espaco.e16),
                TextFormField(
                  controller: _enderecoCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  minLines: 1,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Endereço',
                    hintText: 'Conferido o CEP, preenche sozinho',
                  ),
                  validator: (v) => Validators.obrigatorio(v, 'O endereço'),
                ),
                const SizedBox(height: Espaco.e16),
                TextFormField(
                  controller: _numeroCtrl,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Número e complemento (opcional)',
                  ),
                ),
                const SizedBox(height: Espaco.e24),
                const LinhaCota(legenda: 'A construção'),
                const SizedBox(height: Espaco.e16),
                SeletorGrande<_Construcao>(
                  opcoes: const [
                    OpcaoSeletor(
                        valor: _Construcao.casa,
                        rotulo: 'Casa',
                        icone: Icons.house_outlined),
                    OpcaoSeletor(
                        valor: _Construcao.geminado,
                        rotulo: 'Geminado',
                        icone: Icons.holiday_village_outlined),
                    OpcaoSeletor(
                        valor: _Construcao.predio,
                        rotulo: 'Prédio',
                        icone: Icons.apartment_outlined),
                    OpcaoSeletor(
                        valor: _Construcao.projeto,
                        rotulo: 'Projeto real',
                        icone: Icons.architecture_outlined),
                  ],
                  selecionado: _construcao,
                  aoMudar: _escolherConstrucao,
                ),
                const SizedBox(height: Espaco.e16),
                if (_construcao == _Construcao.projeto)
                  Text(
                    'Depois de criar a obra, envie a planta (foto, PDF ou o '
                    'arquivo do CAD). A IA lê e você confere antes de '
                    'confirmar.',
                    style: Tipografia.corpo.copyWith(color: c.grafite2),
                  )
                else ...[
                  FormularioModelo(
                    pedido: _pedido,
                    aoMudar: (p) => setState(() => _pedido = p),
                  ),
                  const SizedBox(height: Espaco.e16),
                  PreviaModelo(pedido: _pedido, desenho: false),
                  const SizedBox(height: Espaco.e8),
                  Text(
                    'O app monta uma planta típica com esses números, para a '
                    'maquete e o "por dentro". Dá para trocar depois ou '
                    'enviar o projeto de verdade.',
                    style: Tipografia.apoio.copyWith(color: c.grafite2),
                  ),
                ],
                const SizedBox(height: Espaco.e24),
                const LinhaCota(legenda: 'Orçamento e prazo'),
                const SizedBox(height: Espaco.e16),
                TextFormField(
                  controller: _orcamentoCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: estiloValor,
                  decoration: InputDecoration(
                    labelText: 'Orçamento total',
                    hintText: '250.000,00',
                    prefixText: 'R\$ ',
                    prefixStyle: estiloValor,
                  ),
                  validator: Validators.valor,
                ),
                const SizedBox(height: Espaco.e16),
                _CampoData(
                  rotulo: 'Início',
                  data: _dataInicio,
                  onTap: () => _escolherData(inicio: true),
                ),
                const SizedBox(height: Espaco.e16),
                _CampoData(
                  rotulo: 'Previsão de término',
                  data: _previsaoTermino,
                  onTap: () => _escolherData(inicio: false),
                ),
                const SizedBox(height: Espaco.e8),
                Text(
                  dias > 0
                      ? '$dias dias de obra (cerca de ${(dias / 30).round()} '
                          '${(dias / 30).round() == 1 ? 'mês' : 'meses'}).'
                      : 'O término precisa ser depois do início.',
                  style: Tipografia.apoio
                      .copyWith(color: dias > 0 ? c.grafite2 : c.revisao),
                ),
                const SizedBox(height: Espaco.e24),
                Folha(
                  preenchimento: EdgeInsets.zero,
                  // O toque do SwitchListTile precisa de um Material logo
                  // acima (a folha é uma caixa decorada).
                  child: Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      value: _criarCronograma,
                      onChanged: (v) {
                        unawaited(Tato.leve());
                        setState(() => _criarCronograma = v);
                      },
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: Espaco.e12, vertical: Espaco.e4),
                      title: Text('Gerar cronograma com fases padrão',
                          style:
                              Tipografia.corpoForte.copyWith(color: c.grafite)),
                      subtitle: Text(
                        'Cria ${AppConstants.fasesPadrao.length} fases (fundação, '
                        'estrutura, alvenaria...) distribuídas no período da '
                        'obra. A maquete cresce com elas.',
                        style: Tipografia.apoio.copyWith(color: c.grafite2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BarraDeAcao(
        principal: BotaoPrincipal(
          rotulo: 'Criar obra',
          icone: Icons.check,
          grande: true,
          expandir: true,
          carregando: _salvando,
          aoTocar: _salvando ? null : () => unawaited(_salvar()),
        ),
      ),
    );
  }
}

/// O que os Correios disseram do CEP: ícone e texto (nunca só cor).
class _ResultadoDoCep extends StatelessWidget {
  const _ResultadoDoCep({required this.resultado});

  final ResultadoCep resultado;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final semSinal = resultado.situacao == SituacaoCep.semResposta;
    final cor = resultado.valido
        ? c.ok
        : semSinal
            ? c.grafite2
            : c.revisao;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            resultado.valido
                ? Icons.check_circle_outline
                : semSinal
                    ? Icons.cloud_off_outlined
                    : Icons.error_outline,
            size: 20,
            color: cor,
          ),
          const SizedBox(width: Espaco.e8),
          Expanded(
            child: Text(
              resultado.mensagem,
              style: Tipografia.apoio.copyWith(color: cor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de data: toca e abre o calendário.
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
    final c = context.cores;
    final texto = Formatters.data(data);
    return AreaPressionavel(
      aoTocar: onTap,
      escala: 1,
      vibrar: true,
      rotuloSemantico: '$rotulo: $texto',
      dicaSemantica: 'Abre o calendário para trocar a data',
      construtor: (context, e) => InputDecorator(
        isFocused: e.focado || e.pressionado,
        decoration: InputDecoration(
          labelText: rotulo,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          texto,
          style: Tipografia.corpo
              .copyWith(color: c.grafite, fontFeatures: Tipografia.tabular),
        ),
      ),
    );
  }
}
