/// O que o OCR leu da foto, com a posição de cada linha no papel.
///
/// O ML Kit devolve o texto em blocos (regiões de texto contíguo) e, numa
/// nota de duas colunas, põe os rótulos num bloco e os valores noutro: no
/// texto corrido "VALOR A PAGAR" e "350,00" ficam a várias linhas de
/// distância, e o parser casava o rótulo com o número errado. Guardando a
/// caixa de cada linha dá para remontar as linhas como estão impressas.
library;

import 'dart:math' as math;

/// Uma linha do OCR e a caixa que ela ocupa na foto, em pixels.
///
/// Construtor posicional, na ordem em que o ML Kit descreve a caixa:
/// `LinhaOcr(texto, esquerda, topo, direita, base)`.
class LinhaOcr {
  final String texto;
  final double esquerda, topo, direita, base;

  const LinhaOcr(this.texto, this.esquerda, this.topo, this.direita, this.base);

  double get altura => base - topo;
  double get largura => direita - esquerda;
  double get centroX => (esquerda + direita) / 2;

  /// Caixa de verdade: sem ela a linha não tem posição para remontar.
  bool get temCaixa => altura > 0 && largura > 0;
}

/// Um bloco do ML Kit: linhas próximas, na ordem em que ele as leu.
/// Construtor posicional: `BlocoOcr(linhas)`.
class BlocoOcr {
  final List<LinhaOcr> linhas;

  const BlocoOcr(this.linhas);
}

/// Um código lido na foto pelo leitor de código de barras.
/// Construtor posicional: `CodigoLido(formato, valor)`.
class CodigoLido {
  /// 'qr', 'code128' ou o nome do formato que o leitor informar.
  final String formato;
  final String valor;

  const CodigoLido(this.formato, this.valor);
}

/// Tudo o que a leitura da foto produziu: o texto (com ou sem geometria)
/// e os códigos de barras / QR encontrados.
class EntradaOcr {
  final List<BlocoOcr> blocos;

  /// Texto corrido, igual ao `RecognizedText.text`: as linhas de cada
  /// bloco unidas por quebra de linha, e os blocos também.
  final String texto;

  final List<CodigoLido> codigos;

  /// A partir dos blocos do ML Kit: `EntradaOcr(blocos, codigos: [...])`.
  EntradaOcr(List<BlocoOcr> blocos, {List<CodigoLido> codigos = const []})
      : blocos = List.unmodifiable(blocos),
        codigos = List.unmodifiable(codigos),
        texto = [
          for (final b in blocos) b.linhas.map((l) => l.texto).join('\n'),
        ].join('\n');

  /// Texto sem geometria (digitado, colado ou de um OCR que não informa
  /// posição): o parser se comporta como se lesse o texto corrido.
  EntradaOcr.deTexto(this.texto, {List<CodigoLido> codigos = const []})
      : blocos = const [],
        codigos = List.unmodifiable(codigos);

  /// Todas as linhas, na ordem do ML Kit.
  Iterable<LinhaOcr> get linhas => blocos.expand((b) => b.linhas);

  /// Só remonta quando todas as linhas têm caixa: misturar linhas com e
  /// sem posição embaralharia a ordem do texto em vez de corrigi-la.
  bool get temGeometria => linhas.isNotEmpty && linhas.every((l) => l.temCaixa);

  /// Linhas como aparecem no papel, de cima para baixo; null sem geometria.
  late final List<LinhaVisual>? linhasVisuais =
      temGeometria ? reconstruirLinhas(linhas) : null;

  /// O texto linha a linha como está impresso — "VALOR A PAGAR R$ 350,00"
  /// numa linha só, mesmo quando o ML Kit separou rótulo e valor em blocos.
  late final String? textoReconstruido =
      linhasVisuais?.map((l) => l.texto).join('\n');
}

/// Uma linha impressa, remontada a partir dos trechos que o ML Kit leu
/// separados (rótulo numa coluna, valor na outra).
class LinhaVisual {
  /// Trechos da esquerda para a direita.
  final List<LinhaOcr> trechos;

  const LinhaVisual(this.trechos);

  String get texto =>
      trechos.map((t) => t.texto.trim()).where((t) => t.isNotEmpty).join(' ');

  double get topo => trechos.map((t) => t.topo).reduce((a, b) => a < b ? a : b);
  double get base => trechos.map((t) => t.base).reduce((a, b) => a > b ? a : b);
}

/// Quanto do intervalo vertical tem de coincidir para dois trechos serem a
/// mesma linha impressa, em fração da altura do menor. Metade aceita a
/// pequena diferença de altura entre fonte de rótulo e de valor, e ainda
/// separa duas linhas vizinhas, que mal se tocam.
const double sobreposicaoMinimaDaLinha = 0.5;

/// Agrupa as linhas do OCR em linhas impressas: trechos cujo intervalo
/// vertical se sobrepõe bastante viram uma linha só, ordenada por x.
List<LinhaVisual> reconstruirLinhas(Iterable<LinhaOcr> linhas) {
  final ordenadas = linhas.where((l) => l.temCaixa).toList()
    ..sort((a, b) {
      final porCentro = (a.topo + a.base).compareTo(b.topo + b.base);
      return porCentro != 0 ? porCentro : a.esquerda.compareTo(b.esquerda);
    });

  final grupos = <_Grupo>[];
  for (final linha in ordenadas) {
    _Grupo? melhor;
    var melhorSobreposicao = sobreposicaoMinimaDaLinha;
    for (final grupo in grupos) {
      final s = grupo.sobreposicao(linha);
      // Um trecho que invade outro na horizontal está empilhado, não ao
      // lado: duas linhas da mesma coluna nunca são a mesma linha.
      if (s >= melhorSobreposicao && !grupo.colide(linha)) {
        melhor = grupo;
        melhorSobreposicao = s;
      }
    }
    if (melhor == null) {
      grupos.add(_Grupo(linha));
    } else {
      melhor.adicionar(linha);
    }
  }

  grupos.sort((a, b) => a.centro.compareTo(b.centro));
  return [
    for (final g in grupos)
      LinhaVisual(List.unmodifiable(
          g.trechos..sort((a, b) => a.esquerda.compareTo(b.esquerda)))),
  ];
}

/// Uma linha como o ML Kit a descreve: o texto e os quatro cantos da caixa
/// já inclinada, em sentido horário a partir do canto superior esquerdo.
typedef LinhaComCantos = (String texto, List<math.Point<num>> cantos);

/// Inclinação acima da qual vale endireitar (em radianos, ~0,5°): abaixo
/// disso o deslocamento entre as colunas é menor que a folga da
/// sobreposição e girar só arredondaria pixels.
const double _inclinacaoDesprezivel = 0.5 * math.pi / 180;

/// Quanto as linhas têm de concordar na direção (comprimento do vetor
/// médio das direções, de 0 a 1) para valer girar: abaixo disso há texto
/// em várias direções e nenhum giro deixa todas na horizontal.
const double _concordanciaMinima = 0.8;

/// Monta os blocos com as caixas alinhadas às linhas do papel, e não à
/// foto.
///
/// Com o celular um pouco torto, a linha "Valor a pagar ... 350,00" desce
/// (ou sobe) da esquerda para a direita: na foto, o rótulo e o valor mal se
/// sobrepõem na vertical e [reconstruirLinhas] os separaria. Os cantos que
/// o ML Kit informa já estão inclinados; girando todos pela direção do
/// texto, as caixas voltam a ficar na horizontal. O mesmo vale para a foto
/// deitada ou de cabeça para baixo que o ML Kit ainda conseguiu ler: as
/// caixas retas da foto empilhariam as linhas todas numa só.
List<BlocoOcr> blocosEndireitados(List<List<LinhaComCantos>> blocos) {
  final angulo = _direcaoDoTexto(blocos.expand((b) => b));
  final girar = angulo != null && angulo.abs() >= _inclinacaoDesprezivel;
  final cos = math.cos(angulo ?? 0);
  final sin = math.sin(angulo ?? 0);

  LinhaOcr caixa((String, List<math.Point<num>>) linha) {
    final (texto, cantos) = linha;
    if (cantos.isEmpty) return LinhaOcr(texto, 0, 0, 0, 0);
    var esquerda = double.infinity, topo = double.infinity;
    var direita = double.negativeInfinity, base = double.negativeInfinity;
    for (final p in cantos) {
      // rotação de -ângulo em torno da origem da foto
      final x = girar ? p.x * cos + p.y * sin : p.x.toDouble();
      final y = girar ? -p.x * sin + p.y * cos : p.y.toDouble();
      esquerda = math.min(esquerda, x);
      direita = math.max(direita, x);
      topo = math.min(topo, y);
      base = math.max(base, y);
    }
    return LinhaOcr(texto, esquerda, topo, direita, base);
  }

  return [
    for (final b in blocos) BlocoOcr([for (final l in b) caixa(l)]),
  ];
}

/// A direção em que o texto corre na foto (radianos; 0 = da esquerda para
/// a direita), pela borda de cima de cada linha; null quando as linhas não
/// concordam. Conta só as linhas compridas quando há: linha curta ("2",
/// "R\$") tem ângulo impreciso. E é a mediana dos desvios em torno da
/// média circular — circular porque 179° e -179° são quase a mesma
/// direção — para que uma ou outra linha mal lida não decida pela nota.
double? _direcaoDoTexto(Iterable<LinhaComCantos> linhas) {
  final compridas = <double>[];
  final todas = <double>[];
  for (final (_, c) in linhas) {
    if (c.length < 4) continue;
    final dx = (c[1].x - c[0].x).toDouble();
    final dy = (c[1].y - c[0].y).toDouble();
    final largura = math.sqrt(dx * dx + dy * dy);
    final altura = c[3].distanceTo(c[0]).toDouble();
    if (largura <= 0) continue;
    final angulo = math.atan2(dy, dx);
    todas.add(angulo);
    if (largura >= altura * 3) compridas.add(angulo);
  }
  final amostra = compridas.isNotEmpty ? compridas : todas;
  if (amostra.isEmpty) return null;

  var somaCos = 0.0, somaSin = 0.0;
  for (final a in amostra) {
    somaCos += math.cos(a);
    somaSin += math.sin(a);
  }
  final concordancia =
      math.sqrt(somaCos * somaCos + somaSin * somaSin) / amostra.length;
  if (concordancia < _concordanciaMinima) return null;

  final media = math.atan2(somaSin, somaCos);
  final desvios = [
    for (final a in amostra)
      math.atan2(math.sin(a - media), math.cos(a - media)),
  ]..sort();
  return media + desvios[desvios.length ~/ 2];
}

class _Grupo {
  final List<LinhaOcr> trechos;
  double _somaTopos;
  double _somaBases;

  _Grupo(LinhaOcr primeira)
      : trechos = [primeira],
        _somaTopos = primeira.topo,
        _somaBases = primeira.base;

  // A faixa do grupo é a média dos trechos: com a união, uma linha alta
  // (título em fonte grande) puxaria para si as linhas de cima e de baixo.
  double get topo => _somaTopos / trechos.length;
  double get base => _somaBases / trechos.length;
  double get centro => (topo + base) / 2;

  void adicionar(LinhaOcr linha) {
    trechos.add(linha);
    _somaTopos += linha.topo;
    _somaBases += linha.base;
  }

  double sobreposicao(LinhaOcr linha) {
    final comum = (linha.base < base ? linha.base : base) -
        (linha.topo > topo ? linha.topo : topo);
    if (comum <= 0) return 0;
    final menor = linha.altura < base - topo ? linha.altura : base - topo;
    return menor <= 0 ? 0 : comum / menor;
  }

  bool colide(LinhaOcr linha) => trechos.any((t) {
        final comum = (linha.direita < t.direita ? linha.direita : t.direita) -
            (linha.esquerda > t.esquerda ? linha.esquerda : t.esquerda);
        final menor = linha.largura < t.largura ? linha.largura : t.largura;
        // tolera o encosto de poucos pixels entre caixas vizinhas
        return comum > menor * 0.2;
      });
}
