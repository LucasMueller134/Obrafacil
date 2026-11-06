import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../design/maquete/maquete.dart';
import '../../models/models.dart';
import '../../services/firestore_service.dart';
import 'ficha_comodo.dart';

/// O pedido inicial de cada tipo (o que aparece quando a pessoa escolhe).
PedidoModelo pedidoInicial(TipoModelo tipo) => switch (tipo) {
      TipoModelo.casa =>
        const PedidoModelo(tipo: TipoModelo.casa, area: 70, quartos: 2),
      TipoModelo.geminado => const PedidoModelo(
          tipo: TipoModelo.geminado, area: 60, quartos: 2, unidades: 2),
      TipoModelo.predio => const PedidoModelo(
          tipo: TipoModelo.predio,
          area: 55,
          quartos: 2,
          apartamentos: 8,
          andares: 4),
    };

/// Os números do modelo: m², quartos, térreo ou sobrado, quantas casas,
/// quantos apartamentos e andares, conforme o [pedido.tipo].
class FormularioModelo extends StatelessWidget {
  const FormularioModelo({
    super.key,
    required this.pedido,
    required this.aoMudar,
  });

  final PedidoModelo pedido;
  final ValueChanged<PedidoModelo> aoMudar;

  PedidoModelo _com({
    double? area,
    int? quartos,
    bool? sobrado,
    int? unidades,
    int? apartamentos,
    int? andares,
  }) =>
      PedidoModelo(
        tipo: pedido.tipo,
        area: area ?? pedido.area,
        quartos: quartos ?? pedido.quartos,
        sobrado: sobrado ?? pedido.sobrado,
        unidades: unidades ?? pedido.unidades,
        apartamentos: apartamentos ?? pedido.apartamentos,
        andares: andares ?? pedido.andares,
      );

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final predio = p.tipo == TipoModelo.predio;
    final rotuloArea = switch (p.tipo) {
      TipoModelo.casa => 'Área da casa',
      TipoModelo.geminado => 'Área de cada casa',
      TipoModelo.predio => 'Área de cada apartamento',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.tipo == TipoModelo.geminado) ...[
          SeletorGrande<int>(
            rotulo: 'Quantas casas',
            opcoes: const [
              OpcaoSeletor(valor: 2, rotulo: '2'),
              OpcaoSeletor(valor: 3, rotulo: '3'),
              OpcaoSeletor(valor: 4, rotulo: '4'),
            ],
            selecionado: p.unidades,
            aoMudar: (v) => aoMudar(_com(unidades: v)),
          ),
          const SizedBox(height: Espaco.e16),
        ],
        if (predio) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CampoNumero(
                  rotulo: 'Apartamentos',
                  valor: p.apartamentos,
                  aoMudar: (v) => aoMudar(_com(apartamentos: v)),
                ),
              ),
              const SizedBox(width: Espaco.e12),
              Expanded(
                child: _CampoNumero(
                  rotulo: 'Andares',
                  valor: p.andares,
                  aoMudar: (v) => aoMudar(_com(andares: v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espaco.e16),
        ],
        _CampoNumero(
          rotulo: rotuloArea,
          sufixo: 'm²',
          valor: p.area.round(),
          aoMudar: (v) => aoMudar(_com(area: v.toDouble())),
        ),
        const SizedBox(height: Espaco.e16),
        SeletorGrande<int>(
          rotulo: 'Quartos',
          opcoes: [
            for (var q = 1; q <= (predio ? 3 : 4); q++)
              OpcaoSeletor(valor: q, rotulo: '$q'),
          ],
          selecionado: p.quartos,
          aoMudar: (v) => aoMudar(_com(quartos: v)),
        ),
        if (!predio) ...[
          const SizedBox(height: Espaco.e16),
          SeletorGrande<bool>(
            rotulo: 'Pavimentos',
            opcoes: const [
              OpcaoSeletor(valor: false, rotulo: 'Térrea'),
              OpcaoSeletor(valor: true, rotulo: 'Sobrado'),
            ],
            selecionado: p.sobrado,
            aoMudar: (v) => aoMudar(_com(sobrado: v)),
          ),
        ],
      ],
    );
  }
}

/// Campo de número inteiro (m², apartamentos, andares). Guarda o texto
/// enquanto a pessoa digita e só avisa números válidos.
class _CampoNumero extends StatefulWidget {
  const _CampoNumero({
    required this.rotulo,
    required this.valor,
    required this.aoMudar,
    this.sufixo,
  });

  final String rotulo;
  final int valor;
  final ValueChanged<int> aoMudar;
  final String? sufixo;

  @override
  State<_CampoNumero> createState() => _CampoNumeroState();
}

class _CampoNumeroState extends State<_CampoNumero> {
  late final _ctrl = TextEditingController(text: '${widget.valor}');

  @override
  void didUpdateWidget(_CampoNumero antigo) {
    super.didUpdateWidget(antigo);
    if (int.tryParse(_ctrl.text) != widget.valor) {
      _ctrl.text = '${widget.valor}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return TextField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: Tipografia.subtitulo
          .copyWith(color: c.grafite, fontFeatures: Tipografia.tabular),
      decoration: InputDecoration(
        labelText: widget.rotulo,
        suffixText: widget.sufixo,
      ),
      onChanged: (t) {
        final v = int.tryParse(t);
        if (v != null && v > 0) widget.aoMudar(v);
      },
    );
  }
}

/// A planta do modelo na hora: o resumo (área, terreno, pavimentos) e o
/// desenho do térreo. Mostra o que corrigir quando o pedido não fecha.
class PreviaModelo extends StatefulWidget {
  const PreviaModelo({super.key, required this.pedido, this.desenho = true});

  final PedidoModelo pedido;

  /// Desenha a planta (na nova obra fica só o resumo).
  final bool desenho;

  @override
  State<PreviaModelo> createState() => _PreviaModeloState();
}

class _PreviaModeloState extends State<PreviaModelo> {
  PedidoModelo? _feito;
  PlantaObra? _planta;
  int _andar = 0;

  PlantaObra? get _montada {
    final p = widget.pedido;
    if (p.problema != null) return null;
    if (_feito != p) {
      _feito = p;
      _planta = ModelosPlanta.montar(p);
      _andar = 0;
    }
    return _planta;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final problema = widget.pedido.problema;
    if (problema != null) {
      return NotaRevisao(problema, icone: Icons.error_outline);
    }
    final planta = _montada!;
    String m(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    final andar = planta.planta(_andar);
    final numeros = {
      for (final (i, x) in comodosParaMostrar(andar).indexed) x.id: i + 1,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Carimbo(linhas: [
          [
            CelulaCarimbo(
              rotulo: 'Construído',
              valor: '${planta.areaConstruida.toStringAsFixed(0)} m²',
            ),
            CelulaCarimbo(
              rotulo: 'Terreno',
              valor: '${m(planta.largura)} × ${m(planta.profundidade)} m',
            ),
          ],
          [
            CelulaCarimbo(
              rotulo: 'Pavimentos',
              valor: '${planta.totalPavimentos}',
            ),
            CelulaCarimbo(
              rotulo: widget.pedido.tipo == TipoModelo.predio
                  ? 'Apartamentos'
                  : 'Cômodos',
              valor: widget.pedido.tipo == TipoModelo.predio
                  ? '${widget.pedido.totalApartamentos}'
                  : '${comodosParaMostrar(planta.planta(0)).length + (planta.andares.isEmpty ? 0 : comodosParaMostrar(planta.planta(1)).length)}',
            ),
          ],
        ]),
        if (widget.pedido.tipo == TipoModelo.predio &&
            widget.pedido.totalApartamentos != widget.pedido.apartamentos) ...[
          const SizedBox(height: Espaco.e8),
          NotaRevisao(
            '${widget.pedido.aptosPorAndar} por andar: ficam '
            '${widget.pedido.totalApartamentos} apartamentos.',
            tipo: TipoNota.marca,
            icone: Icons.info_outline,
          ),
        ],
        if (widget.desenho) ...[
          const SizedBox(height: Espaco.e16),
          SeletorDeAndar(
            planta: planta,
            selecionado: _andar,
            aoMudar: (v) => setState(() => _andar = v),
          ),
          Folha(
            preenchimento: EdgeInsets.zero,
            child: LayoutBuilder(
              builder: (context, caixa) => SizedBox(
                height: PlantaDesenhada.alturaPara(andar, caixa.maxWidth),
                child: PlantaDesenhada(planta: andar, numeros: numeros),
              ),
            ),
          ),
          const SizedBox(height: Espaco.e8),
          Text(
            'Uma planta típica, montada pelo app. Para a casa exata, envie o '
            'projeto de verdade.',
            style: Tipografia.apoio.copyWith(color: c.grafite2),
          ),
        ],
      ],
    );
  }
}

/// Montar a planta da obra por um modelo pronto (casa, geminado ou prédio).
/// Grava em `obras/{id}/planta/atual` com desfazer.
class ModeloPlantaScreen extends StatefulWidget {
  const ModeloPlantaScreen({super.key, required this.obraId, this.inicial});

  final String obraId;

  /// O modelo da planta de agora, para ajustar (nulo: casa padrão).
  final PedidoModelo? inicial;

  @override
  State<ModeloPlantaScreen> createState() => _ModeloPlantaScreenState();
}

class _ModeloPlantaScreenState extends State<ModeloPlantaScreen> {
  late PedidoModelo _pedido = widget.inicial ?? pedidoInicial(TipoModelo.casa);
  bool _salvando = false;

  Future<void> _usar() async {
    final pedido = _pedido;
    if (pedido.problema != null) {
      unawaited(Tato.erro());
      return;
    }
    setState(() => _salvando = true);
    final db = context.read<FirestoreService>();
    final anterior = await db.planta(widget.obraId).first;
    try {
      await db.salvarPlanta(widget.obraId, ModelosPlanta.montar(pedido));
      unawaited(Tato.confirmar());
      if (!mounted) return;
      mostrarAviso(
        context,
        'Planta montada: ${pedido.resumo}. A maquete já é esta.',
        aoDesfazer: () => unawaited(anterior == null
            ? db.excluirPlanta(widget.obraId)
            : db.salvarPlanta(widget.obraId, anterior)),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e32),
        children: [
          const Rotulo('Planta da obra'),
          const SizedBox(height: Espaco.e4),
          Semantics(
            header: true,
            child: Text('Montar pelo modelo',
                style: Tipografia.tituloTela.copyWith(color: c.grafite)),
          ),
          const SizedBox(height: Espaco.e8),
          Text(
            'Diga como é a obra e o app monta uma planta típica na hora, com '
            'a maquete e o "por dentro".',
            style: Tipografia.corpo.copyWith(color: c.grafite2),
          ),
          const SizedBox(height: Espaco.e24),
          SeletorGrande<TipoModelo>(
            rotulo: 'Tipo da obra',
            opcoes: [
              for (final t in TipoModelo.values)
                OpcaoSeletor(
                  valor: t,
                  rotulo: t.rotulo,
                  icone: switch (t) {
                    TipoModelo.casa => Icons.house_outlined,
                    TipoModelo.geminado => Icons.holiday_village_outlined,
                    TipoModelo.predio => Icons.apartment_outlined,
                  },
                ),
            ],
            selecionado: _pedido.tipo,
            aoMudar: (t) => setState(() => _pedido = pedidoInicial(t)),
          ),
          const SizedBox(height: Espaco.e16),
          FormularioModelo(
            pedido: _pedido,
            aoMudar: (p) => setState(() => _pedido = p),
          ),
          const SizedBox(height: Espaco.e24),
          const LinhaCota(legenda: 'Como fica'),
          const SizedBox(height: Espaco.e16),
          PreviaModelo(pedido: _pedido),
        ],
      ),
      bottomNavigationBar: BarraDeAcao(
        principal: BotaoPrincipal(
          rotulo: 'Usar este modelo',
          icone: Icons.check,
          grande: true,
          expandir: true,
          carregando: _salvando,
          aoTocar: _salvando || _pedido.problema != null
              ? null
              : () => unawaited(_usar()),
        ),
      ),
    );
  }
}
