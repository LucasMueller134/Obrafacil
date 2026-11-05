import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../models/models.dart';

String _m(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

/// "3,23 × 4,10 m".
String medidasDoComodo(ComodoPlanta c) =>
    '${_m(c.principal.largura)} × ${_m(c.principal.profundidade)} m';

/// "13,2 m²".
String areaDoComodo(ComodoPlanta c) =>
    '${c.area.toStringAsFixed(1).replaceAll('.', ',')} m²';

/// "2 portas · 1 janela".
String aberturasDoComodo(PlantaObra planta, ComodoPlanta c) {
  final vaos = planta.aberturasDo(c);
  final portas = vaos
      .where((a) =>
          a.tipo == TipoAbertura.porta ||
          a.tipo == TipoAbertura.portaCorrer ||
          a.tipo == TipoAbertura.portao)
      .length;
  final janelas = vaos.where((a) => a.tipo.ehJanela).length;
  final passagens = vaos.where((a) => a.tipo == TipoAbertura.passagem).length;
  String n(int k, String um, String varios) => '$k ${k == 1 ? um : varios}';
  final partes = [
    if (portas > 0) n(portas, 'porta', 'portas'),
    if (janelas > 0) n(janelas, 'janela', 'janelas'),
    if (passagens > 0) n(passagens, 'passagem', 'passagens'),
  ];
  return partes.isEmpty ? 'Sem portas nem janelas' : partes.join(' · ');
}

/// A ficha de um cômodo: nome, medidas, área, piso, pé-direito e vãos, no
/// carimbo da prancheta. [acao] (ex.: "Ver em 360°") vai embaixo.
class FichaComodo extends StatelessWidget {
  const FichaComodo({
    super.key,
    required this.planta,
    required this.comodo,
    this.acao,
  });

  final PlantaObra planta;
  final ComodoPlanta comodo;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final peDireito =
        comodo.coberto ? '${_m(planta.alturas.peDireito)} m' : 'Descoberto';
    return Semantics(
      container: true,
      label: '${comodo.nome}: ${medidasDoComodo(comodo)}, '
          '${areaDoComodo(comodo)}, piso ${comodo.piso.rotulo}, '
          '${aberturasDoComodo(planta, comodo)}',
      excludeSemantics: acao == null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Carimbo(linhas: [
            [
              CelulaCarimbo(
                rotulo: 'Cômodo',
                conteudo: Text(
                  comodo.nome,
                  style: Tipografia.titulo.copyWith(color: c.grafite),
                ),
              ),
            ],
            [
              CelulaCarimbo(rotulo: 'Medidas', valor: medidasDoComodo(comodo)),
              CelulaCarimbo(rotulo: 'Área', valor: areaDoComodo(comodo)),
            ],
            [
              CelulaCarimbo(rotulo: 'Piso', valor: comodo.piso.rotulo),
              CelulaCarimbo(rotulo: 'Pé-direito', valor: peDireito),
            ],
          ]),
          const SizedBox(height: Espaco.e12),
          Text(
            aberturasDoComodo(planta, comodo),
            style: Tipografia.apoio.copyWith(color: c.grafite2),
          ),
          if (acao != null) ...[
            const SizedBox(height: Espaco.e16),
            acao!,
          ],
        ],
      ),
    );
  }
}

/// O número do cômodo na legenda da planta, num círculo de traço.
class NumeroDeLegenda extends StatelessWidget {
  const NumeroDeLegenda(this.numero, {super.key});

  final int numero;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return ExcludeSemantics(
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.grafite, width: Traco.fino),
        ),
        child: Text(
          '$numero',
          style: Tipografia.rotulo.copyWith(
            color: c.grafite,
            fontFeatures: Tipografia.tabular,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
