import 'dart:io';
import 'dart:isolate';
import 'dart:math' show max;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ComparacaoFotos {
  /// 0 a 1 — quanto a cena mudou entre as duas fotos, já descontada a
  /// diferença de luz.
  final double indiceMudanca;

  /// 0 a 1 — quanto o brilho médio das duas fotos difere. Não entra no
  /// índice; serve para avisar que a comparação foi feita com luz
  /// diferente.
  final double diferencaDeLuz;

  const ComparacaoFotos({
    required this.indiceMudanca,
    this.diferencaDeLuz = 0,
  });

  /// As fotos foram tiradas com luz bem diferente (outro horário, sol e
  /// sombra, flash). A comparação desconta isso, mas mede melhor com a
  /// mesma luz.
  bool get luzMuitoDiferente => diferencaDeLuz >= 0.20;

  /// O índice mede mudança visual — formas, bordas, o que apareceu ou
  /// sumiu da cena —, não o avanço da obra: entulho removido muda a foto
  /// tanto quanto uma parede levantada. Por isso o texto fala da cena, e
  /// nunca promete progresso.
  String get interpretacao {
    if (indiceMudanca < 0.10) {
      return 'Quase nenhuma mudança visual entre as fotos.';
    }
    if (indiceMudanca < 0.30) {
      return 'Mudança visual leve — algo mudou em parte da cena.';
    }
    if (indiceMudanca < 0.55) {
      return 'Mudança visual moderada — a cena mudou de forma perceptível.';
    }
    return 'Mudança visual grande — a cena mudou bastante (ou as fotos '
        'foram tiradas de pontos diferentes).';
  }
}

/// IA on-device nº 4 — comparação visual entre duas fotos (experimental).
///
/// Compara duas fotos do mesmo ponto da obra pela estrutura da cena, e não
/// pelo brilho: a diferença pixel a pixel crua confundia luz com obra (a
/// mesma parede de manhã e à tarde dava "mudança grande"). Agora cada foto
/// tem a faixa de tons esticada para a escala inteira antes da conta — o
/// que tira a diferença de exposição —, com um limite de ganho para não
/// esticar o ruído do sensor, e o índice soma a diferença das imagens
/// normalizadas com a das bordas, que são as formas da cena: parede nova,
/// laje, telhado. O cálculo roda num isolate para não travar a interface.
class ProgressoFotoService {
  /// Lado da imagem reduzida: o bastante para ver paredes e vãos, pouco
  /// para que ruído de câmera e folha balançando não contem como mudança.
  static const int _lado = 64;

  /// Fração dos pixels de borda mais forte que entra no mapa de bordas.
  /// O corte é relativo (os 12% mais fortes de cada foto), então uma foto
  /// com menos contraste tem as mesmas bordas que a outra.
  static const double _fracaoDeBorda = 0.12;

  /// Diferença média esperada entre duas imagens normalizadas sem relação
  /// nenhuma (duas variáveis uniformes): é o que vale 100% de mudança.
  static const double _difNormalizadaMaxima = 1 / 3;

  /// Faixa de tons mínima, como fração do brilho médio, que a
  /// normalização estica para a escala inteira. Uma foto quase de um tom
  /// só (parede rebocada ou pintada, contrapiso) tem pouco contraste além
  /// do ruído do sensor: esticá-la como as outras — o que a equalização de
  /// histograma fazia — transformava ±2 níveis de ruído em dezenas, e o
  /// Sobel lia isso como borda. Por ser fração do brilho, a mesma parede
  /// com outra luz é esticada do mesmo jeito.
  static const double _contrasteMinimo = 0.30;

  /// Gradiente mínimo para um pixel ser borda, além do corte relativo.
  /// Depois da média 3x3, é um degrau de uns 18 níveis: sem este piso, o
  /// corte relativo de uma foto lisa cai quase a zero e todo ruído vira
  /// borda.
  static const int _bordaMinima = 48;

  static Future<ComparacaoFotos> comparar(
      String caminhoAntes, String caminhoDepois) async {
    final bytesAntes = await File(caminhoAntes).readAsBytes();
    final bytesDepois = await File(caminhoDepois).readAsBytes();
    return compararBytes(bytesAntes, bytesDepois);
  }

  /// Lança [FormatException] se uma das fotos não puder ser lida: devolver
  /// "nenhuma mudança" para uma foto corrompida seria uma resposta errada
  /// com cara de certa.
  static Future<ComparacaoFotos> compararBytes(
      Uint8List bytesAntes, Uint8List bytesDepois) {
    return Isolate.run(() => _comparar(bytesAntes, bytesDepois));
  }

  static ComparacaoFotos _comparar(
      Uint8List bytesAntes, Uint8List bytesDepois) {
    final antes = _luminancia(bytesAntes);
    final depois = _luminancia(bytesDepois);

    final luz = (_media(antes) - _media(depois)).abs() / 255;

    final eqAntes = _suavizar(_normalizar(antes));
    final eqDepois = _suavizar(_normalizar(depois));

    final difImagem =
        (_diferencaMedia(eqAntes, eqDepois) / 255 / _difNormalizadaMaxima)
            .clamp(0.0, 1.0);
    final difBordas = _diferencaDeBordas(_bordas(eqAntes), _bordas(eqDepois));

    // As bordas pesam mais: são a estrutura da cena. A diferença das
    // imagens normalizadas pega o que bordas não mostram — uma superfície
    // grande que mudou de tom, como o reboco sobre o tijolo.
    final indice = (0.4 * difImagem + 0.6 * difBordas).clamp(0.0, 1.0);
    return ComparacaoFotos(indiceMudanca: indice, diferencaDeLuz: luz);
  }

  /// Decodifica e reduz para [_lado]x[_lado] em tons de cinza (0 a 255).
  static List<int> _luminancia(Uint8List bytes) {
    img.Image? decodificada;
    try {
      decodificada = img.decodeImage(bytes);
    } catch (_) {
      // Bytes truncados fazem o decodificador estourar em vez de devolver
      // null: para quem chama, é a mesma foto ilegível.
      decodificada = null;
    }
    if (decodificada == null) {
      throw const FormatException('Foto em formato que não dá para ler.');
    }
    // Média da área de cada pixel, e não o pixel mais próximo: a média
    // apaga o ruído do sensor (numa foto de 900 px, cada pixel reduzido
    // junta uns 200), o vizinho mais próximo o deixa passar inteiro.
    final pequena = img.copyResize(
      decodificada,
      width: _lado,
      height: _lado,
      interpolation: img.Interpolation.average,
    );
    return [
      for (final pixel in pequena)
        (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).round(),
    ];
  }

  static double _media(List<int> valores) =>
      valores.fold<int>(0, (a, b) => a + b) / valores.length;

  /// Normalização da luz: estica a faixa de tons da foto (do 2º ao 98º
  /// percentil, para ignorar os poucos pixels extremos) para a escala
  /// inteira, centrada no meio. A mesma cena mais escura ou mais clara dá
  /// a mesma imagem. O ganho tem teto: a faixa nunca conta como menor que
  /// [_contrasteMinimo] do brilho médio (nem que 12 níveis, na foto quase
  /// preta), e o ruído de uma parede lisa continua pequeno.
  static List<int> _normalizar(List<int> valores) {
    final ordenados = [...valores]..sort();
    final baixo = ordenados[(ordenados.length * 0.02).floor()];
    final alto = ordenados[(ordenados.length * 0.98).floor()];
    final faixa =
        max(alto - baixo, max(_contrasteMinimo * _media(valores), 12));
    final ganho = 255 / faixa;
    final meio = (alto + baixo) / 2;
    return [
      for (final v in valores) (128 + (v - meio) * ganho).round().clamp(0, 255),
    ];
  }

  /// Média 3x3: tira o ruído de pixel que viraria borda falsa.
  static List<int> _suavizar(List<int> v) {
    final saida = List<int>.filled(v.length, 0);
    for (var y = 0; y < _lado; y++) {
      for (var x = 0; x < _lado; x++) {
        var soma = 0, n = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final yy = y + dy, xx = x + dx;
            if (yy < 0 || yy >= _lado || xx < 0 || xx >= _lado) continue;
            soma += v[yy * _lado + xx];
            n++;
          }
        }
        saida[y * _lado + x] = soma ~/ n;
      }
    }
    return saida;
  }

  static double _diferencaMedia(List<int> a, List<int> b) {
    var soma = 0;
    for (var i = 0; i < a.length; i++) {
      soma += (a[i] - b[i]).abs();
    }
    return soma / a.length;
  }

  /// Mapa de bordas: gradiente de Sobel, ficando só com os
  /// [_fracaoDeBorda] pixels de gradiente mais forte da foto.
  static List<bool> _bordas(List<int> v) {
    final magnitude = List<int>.filled(v.length, 0);
    int p(int x, int y) => v[y * _lado + x];
    for (var y = 1; y < _lado - 1; y++) {
      for (var x = 1; x < _lado - 1; x++) {
        final gx = (p(x + 1, y - 1) + 2 * p(x + 1, y) + p(x + 1, y + 1)) -
            (p(x - 1, y - 1) + 2 * p(x - 1, y) + p(x - 1, y + 1));
        final gy = (p(x - 1, y + 1) + 2 * p(x, y + 1) + p(x + 1, y + 1)) -
            (p(x - 1, y - 1) + 2 * p(x, y - 1) + p(x + 1, y - 1));
        magnitude[y * _lado + x] = gx.abs() + gy.abs();
      }
    }
    final ordenadas = [...magnitude]..sort();
    final corte =
        ordenadas[((1 - _fracaoDeBorda) * (ordenadas.length - 1)).round()];
    // Foto lisa, sem borda nenhuma: o piso absoluto impede que o ruído
    // que sobrou vire borda só por estar entre os mais fortes da foto.
    return [
      for (final m in magnitude) m >= corte && m >= _bordaMinima,
    ];
  }

  /// Fração das bordas de uma foto que não têm borda correspondente na
  /// outra. "Correspondente" aceita um pixel de folga em cruz: a mão que
  /// segura o celular nunca volta exatamente ao mesmo lugar.
  static double _diferencaDeBordas(List<bool> a, List<bool> b) {
    var semPar = 0, total = 0;
    bool temVizinha(List<bool> mapa, int x, int y) {
      for (final (dx, dy) in const [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final xx = x + dx, yy = y + dy;
        if (xx < 0 || xx >= _lado || yy < 0 || yy >= _lado) continue;
        if (mapa[yy * _lado + xx]) return true;
      }
      return false;
    }

    for (var y = 0; y < _lado; y++) {
      for (var x = 0; x < _lado; x++) {
        final i = y * _lado + x;
        if (a[i]) {
          total++;
          if (!temVizinha(b, x, y)) semPar++;
        }
        if (b[i]) {
          total++;
          if (!temVizinha(a, x, y)) semPar++;
        }
      }
    }
    // Nenhuma borda nas duas: duas fotos lisas e iguais.
    if (total == 0) return 0;
    return semPar / total;
  }
}
