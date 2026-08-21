import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Do que a foto é feita, em proporção de pixels.
///
/// Cada campo vai de 0 a 1. É a leitura "burra" da imagem — não sabe o que
/// é uma laje —, mas é uma evidência que o classificador genérico não dá:
/// barranco de escavação é terra, parede de tijolo é vermelho, forma e
/// concreto são cinza. Somada aos rótulos do modelo, tira boa parte dos
/// chutes.
class PaletaObra {
  /// Marrom/ocre: barranco, aterro, solo do canteiro.
  final double terra;

  /// Vermelho de cerâmica: tijolo, telha, bloco cerâmico.
  final double tijolo;

  /// Cinza dessaturado: concreto, forma metálica, contrapiso.
  final double concreto;

  /// Claro quase branco: parede rebocada, pintada, gesso.
  final double claro;

  /// Verde: mato, terreno ainda não limpo, entorno.
  final double vegetacao;

  /// Azul na faixa de cima da foto — céu limpo.
  final double ceuAzul;

  /// Claro sem cor na faixa de cima — céu encoberto.
  final double ceuCinza;

  const PaletaObra({
    this.terra = 0,
    this.tijolo = 0,
    this.concreto = 0,
    this.claro = 0,
    this.vegetacao = 0,
    this.ceuAzul = 0,
    this.ceuCinza = 0,
  });

  /// Clima provável pelo céu, ou null quando não há céu suficiente na foto
  /// (foto de detalhe, ambiente interno).
  String? get climaPeloCeu {
    if (ceuAzul + ceuCinza < 0.12) return null;
    return ceuAzul >= ceuCinza ? 'Ensolarado' : 'Nublado';
  }

  @override
  String toString() => 'PaletaObra(terra: ${terra.toStringAsFixed(2)}, '
      'tijolo: ${tijolo.toStringAsFixed(2)}, '
      'concreto: ${concreto.toStringAsFixed(2)}, '
      'claro: ${claro.toStringAsFixed(2)}, '
      'vegetacao: ${vegetacao.toStringAsFixed(2)})';
}

/// Análise cromática da foto do canteiro.
abstract class CoresFoto {
  /// Faixa superior considerada céu.
  static const double _fracaoCeu = 0.28;

  static Future<PaletaObra> analisarArquivo(Uint8List bytes) =>
      Isolate.run(() => analisarBytes(bytes));

  static PaletaObra analisarBytes(Uint8List bytes) {
    final decodificada = img.decodeImage(bytes);
    if (decodificada == null) return const PaletaObra();
    return analisar(decodificada);
  }

  /// Parte pura (testável): conta os pixels por família de cor.
  static PaletaObra analisar(img.Image original) {
    // 128px de largura basta: a proporção de cor não muda com o detalhe,
    // e assim a conta cabe num piscar mesmo em celular fraco.
    final imagem = original.width > 128
        ? img.copyResize(original, width: 128)
        : original;

    var terra = 0, tijolo = 0, concreto = 0, claro = 0, vegetacao = 0;
    var ceuAzul = 0, ceuCinza = 0;
    var totalCeu = 0;
    // Brilho médio de cima e de baixo: céu é sempre mais claro que o
    // chão. Sem essa conferência, uma foto inteira de contrapiso cinza
    // vira "dia nublado".
    var brilhoTopo = 0.0, brilhoResto = 0.0;
    var totalResto = 0;
    final limiteCeu = (imagem.height * _fracaoCeu).round();
    final total = imagem.width * imagem.height;
    if (total == 0) return const PaletaObra();

    for (var y = 0; y < imagem.height; y++) {
      for (var x = 0; x < imagem.width; x++) {
        final pixel = imagem.getPixel(x, y);
        final (matiz, saturacao, valor) = _paraHsv(
          pixel.r.toDouble(),
          pixel.g.toDouble(),
          pixel.b.toDouble(),
        );

        if (y < limiteCeu) {
          totalCeu++;
          brilhoTopo += valor;
          if (valor > 0.45 && saturacao > 0.15 && matiz >= 175 && matiz <= 260) {
            ceuAzul++;
            continue;
          }
          // Céu encoberto é quase branco; concreto curado fica na casa do
          // 0,6. O limiar alto separa um do outro.
          if (valor > 0.72 && saturacao <= 0.15) {
            ceuCinza++;
            continue;
          }
        } else {
          brilhoResto += valor;
          totalResto++;
        }

        if (matiz >= 70 && matiz <= 165 && saturacao > 0.20 && valor > 0.12) {
          vegetacao++;
        } else if (matiz <= 22 && saturacao > 0.42 && valor > 0.25) {
          tijolo++;
        } else if (matiz > 12 &&
            matiz <= 48 &&
            saturacao >= 0.14 &&
            saturacao <= 0.75 &&
            valor >= 0.12 &&
            valor <= 0.78) {
          terra++;
        } else if (saturacao < 0.13 && valor >= 0.22 && valor <= 0.78) {
          concreto++;
        } else if (saturacao < 0.18 && valor > 0.78) {
          claro++;
        }
      }
    }

    double fatia(int quantidade) => quantidade / total;

    // Sem contraste entre topo e resto, aquilo lá em cima não é céu — é a
    // continuação da parede, do piso ou do barranco.
    final mediaTopo = totalCeu == 0 ? 0.0 : brilhoTopo / totalCeu;
    final mediaResto = totalResto == 0 ? 0.0 : brilhoResto / totalResto;
    if (totalResto == 0 || mediaTopo < mediaResto + 0.10) {
      ceuAzul = 0;
      ceuCinza = 0;
    }

    return PaletaObra(
      terra: fatia(terra),
      tijolo: fatia(tijolo),
      concreto: fatia(concreto),
      claro: fatia(claro),
      vegetacao: fatia(vegetacao),
      // O céu é medido dentro da própria faixa: 40% da faixa de cima azul
      // é céu limpo, mesmo que seja pouco da foto inteira.
      ceuAzul: totalCeu == 0 ? 0 : ceuAzul / totalCeu,
      ceuCinza: totalCeu == 0 ? 0 : ceuCinza / totalCeu,
    );
  }

  /// RGB (0-255) → matiz em graus (0-360), saturação e valor (0-1).
  static (double, double, double) _paraHsv(double r, double g, double b) {
    final vermelho = r / 255;
    final verde = g / 255;
    final azul = b / 255;
    final maximo = [vermelho, verde, azul].reduce((a, b) => a > b ? a : b);
    final minimo = [vermelho, verde, azul].reduce((a, b) => a < b ? a : b);
    final delta = maximo - minimo;

    var matiz = 0.0;
    if (delta > 0.0001) {
      if (maximo == vermelho) {
        matiz = 60 * (((verde - azul) / delta) % 6);
      } else if (maximo == verde) {
        matiz = 60 * (((azul - vermelho) / delta) + 2);
      } else {
        matiz = 60 * (((vermelho - verde) / delta) + 4);
      }
    }
    if (matiz < 0) matiz += 360;
    final saturacao = maximo <= 0.0001 ? 0.0 : delta / maximo;
    return (matiz, saturacao, maximo);
  }
}
