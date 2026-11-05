import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../models/planta_obra.dart';
import 'gerador/gerador_maquete.dart';
import 'gerador/glb.dart';
import 'plano_maquete.dart';

/// Onde a câmera da maquete fica, já em coordenadas do flutter_scene (o Z
/// do glTF invertido, como na importação do glb).
@immutable
class EnquadramentoMaquete {
  const EnquadramentoMaquete({
    required this.posicao,
    required this.alvo,
    this.fovVerticalGraus = CameraMaquete.fovVerticalGraus,
    this.proporcao = CameraMaquete.proporcaoReserva,
  });

  /// O da maquete-padrão (a câmera das imagens de reserva).
  static const padrao = EnquadramentoMaquete(
    posicao: CameraMaquete.posicao,
    alvo: CameraMaquete.alvo,
  );

  final List<double> posicao;
  final List<double> alvo;
  final double fovVerticalGraus;

  /// Proporção (largura / altura) para a qual o enquadramento foi feito.
  final double proporcao;

  /// A mesma direção de olhar da maquete-padrão, afastada para a caixa
  /// [min]..[max] (coordenadas glTF) caber como a casa-padrão cabe.
  factory EnquadramentoMaquete.paraLimites(
    (double, double, double) min,
    (double, double, double) max,
  ) {
    // Direção da câmera-padrão (flutter_scene) e quanto da tela a
    // maquete-padrão ocupa: distância 28,44 m para uma caixa de raio ~9,6 m.
    final p = CameraMaquete.posicao, a = CameraMaquete.alvo;
    final d = [p[0] - a[0], p[1] - a[1], p[2] - a[2]];
    final dc = math.sqrt(d[0] * d[0] + d[1] * d[1] + d[2] * d[2]);
    const folga = 0.69;
    final centro = [
      (min.$1 + max.$1) / 2,
      min.$2 + (max.$2 - min.$2) * 0.2,
      -(min.$3 + max.$3) / 2, // Z invertido
    ];
    final raio = math.sqrt(math.pow(max.$1 - min.$1, 2) +
            math.pow(max.$2 - min.$2, 2) +
            math.pow(max.$3 - min.$3, 2)) /
        2;
    final meioCampo = CameraMaquete.fovVerticalGraus * math.pi / 360;
    final distancia = raio * folga / math.sin(meioCampo);
    return EnquadramentoMaquete(
      posicao: [
        for (var i = 0; i < 3; i++) centro[i] + d[i] / dc * distancia,
      ],
      alvo: centro,
    );
  }

  /// Campo de visão vertical (radianos) para uma caixa com essa proporção:
  /// a mesma regra da imagem de reserva com `BoxFit.contain`.
  double fovVerticalPara(double proporcaoCaixa) {
    final base = fovVerticalGraus * math.pi / 180;
    if (!(proporcaoCaixa > 0) || proporcaoCaixa >= proporcao) return base;
    final t = math.tan(base / 2) * proporcao / proporcaoCaixa;
    return 2 * math.atan(t);
  }
}

/// De onde vem a maquete.
@immutable
sealed class FonteMaquete {
  const FonteMaquete();

  /// A casa-padrão do app (`assets/3d/maquete.glb`), com as imagens de
  /// reserva renderizadas no Blender.
  static const padrao = FontePadrao();
}

final class FontePadrao extends FonteMaquete {
  const FontePadrao();

  @override
  bool operator ==(Object other) => other is FontePadrao;

  @override
  int get hashCode => 0;
}

/// A maquete gerada pela planta da obra, no aparelho. A reserva (aparelho
/// sem 3D, testes, "reduzir animações") é a planta desenhada.
final class FontePlanta extends FonteMaquete {
  FontePlanta(this.planta) : _json = jsonEncode(planta.toMap());

  final PlantaObra planta;
  final String _json;

  @override
  bool operator ==(Object other) =>
      other is FontePlanta && other._json == _json;

  @override
  int get hashCode => _json.hashCode;

  static final Map<String, Future<MaquetePronta>> _cache = {};

  /// O glb e o enquadramento desta planta. Gera uma vez por planta (num
  /// isolate, para não travar a tela) e guarda as últimas.
  Future<MaquetePronta> preparar() {
    final pronta = _cache[_json];
    if (pronta != null) return pronta;
    if (_cache.length >= 4) _cache.remove(_cache.keys.first);
    final futura = compute(_gerar, _json);
    _cache[_json] = futura;
    // Uma geração que falhou não fica guardada.
    futura.then<void>((_) {}, onError: (Object _) => _cache.remove(_json));
    return futura;
  }

  /// Esquece as maquetes geradas (testes).
  @visibleForTesting
  static void esquecer() => _cache.clear();
}

/// O que a cena precisa de uma maquete gerada.
class MaquetePronta {
  const MaquetePronta(this.glb, this.enquadramento, this.triangulos);

  final Uint8List glb;
  final EnquadramentoMaquete enquadramento;
  final int triangulos;
}

MaquetePronta _gerar(String json) {
  final planta = PlantaObra.fromMap(jsonDecode(json) as Map<String, dynamic>);
  final m = GeradorMaquete.gerar(planta);
  final (mn, mx) = m.modelo.limites;
  return MaquetePronta(
    escreverGlb(m.modelo),
    EnquadramentoMaquete.paraLimites(mn, mx),
    m.modelo.triangulos,
  );
}
