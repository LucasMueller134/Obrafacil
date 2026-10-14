import 'package:obra_facil/services/ia/cores_foto.dart';
import 'package:obra_facil/services/ia/diario_foto_service.dart';
import 'package:obra_facil/services/ia/diario_voz_service.dart';
import 'package:obra_facil/services/ia/ocr_nota_service.dart';
import 'package:obra_facil/services/ia/voz_service.dart';

/// Liga cada caso do conjunto de avaliação à IA correspondente e devolve a
/// predição já no formato canônico do `esperado` (ver LEIA-ME.md).
///
/// É o único arquivo que conhece a API das IAs: quando a API muda, só ele
/// muda, e o mesmo conjunto de casos continua medindo antes e depois.
abstract class Adaptadores {
  /// "Hoje" de todos os casos de voz.
  static final DateTime agora = DateTime(2026, 7, 6, 10);

  static Map<String, Object?> vozLancamento(Map<String, dynamic> entrada) {
    final r =
        VozService.interpretarHipoteses(_hipoteses(entrada), agora: agora);
    return {
      'valor': r.valor,
      'categoria': r.categoria.name,
      'fornecedor': r.fornecedorNome,
      'data': _data(r.data),
      'itens': [
        for (final i in r.itens)
          {
            'material': i.material,
            'quantidade': i.quantidade,
            'unidade': i.unidade,
          },
      ],
    };
  }

  static Map<String, Object?> vozDiario(Map<String, dynamic> entrada) {
    final r = DiarioVozService.interpretarHipoteses(_hipoteses(entrada),
        agora: agora);
    return {
      'clima': r.clima,
      'pessoas': r.numeroPessoas,
      'fase': r.fase,
      'data': _data(r.data),
    };
  }

  /// Nota fiscal: passa ao OCR tudo o que o aparelho teria na mão — o
  /// texto com a posição de cada linha (quando o caso traz `blocos`) e o
  /// que o leitor de código de barras leu (`codigos`).
  static Map<String, Object?> ocrNota(Map<String, dynamic> entrada) {
    final codigos = [
      for (final c in (entrada['codigos'] as List?) ?? const [])
        CodigoLido(c['formato'] as String, c['valor'] as String),
    ];
    final texto = entrada['texto'];
    final nota = OcrNotaService.interpretar(texto is String
        ? EntradaOcr.deTexto(texto, codigos: codigos)
        : EntradaOcr([
            for (final b in (entrada['blocos'] as List?) ?? const [])
              BlocoOcr([
                for (final l in b['linhas'] as List)
                  LinhaOcr(
                    l['t'] as String,
                    (l['l'] as num).toDouble(),
                    (l['tp'] as num).toDouble(),
                    (l['r'] as num).toDouble(),
                    (l['b'] as num).toDouble(),
                  ),
              ]),
          ], codigos: codigos));
    return {
      'fornecedor': nota.fornecedorNome,
      'cnpj': nota.cnpj,
      'total': nota.valorTotal,
      'data': _data(nota.data),
    };
  }

  static Map<String, Object?> fotoDiario(Map<String, dynamic> entrada) {
    final analise = DiarioFotoService.interpretar(
      [
        for (final r in entrada['rotulos'] as List)
          RotuloFoto(r[0] as String, (r[1] as num).toDouble()),
      ],
      paleta: _paleta(entrada['paleta'] as Map<String, dynamic>?),
    );
    // A tela só preenche a fase com confiança >= 0,5 (diario_screen.dart);
    // abaixo disso ela avisa que é palpite e deixa o campo vazio.
    final preenchida =
        analise.confiancaFase >= 0.5 ? analise.faseSugerida : null;
    return {
      'fase': preenchida,
      'clima': analise.climaSugerido,
      'materiais': analise.materiais,
    };
  }

  /// Linha de base do reconhecimento de material: o serviço original não
  /// expunha a regra fora do ML Kit, então ela está reproduzida aqui tal
  /// como era em material_vision_service.dart (mapa de rótulos, confiança
  /// mínima 0,45, mais confiante primeiro).
  static Map<String, Object?> material(Map<String, dynamic> entrada) {
    const mapa = {
      'brick': 'Tijolo',
      'brickwork': 'Tijolo',
      'wood': 'Madeira',
      'lumber': 'Madeira',
      'plank': 'Madeira',
      'plywood': 'Madeira',
      'concrete': 'Concreto',
      'cement': 'Cimento',
      'sand': 'Areia',
      'gravel': 'Brita',
      'rock': 'Brita',
      'stone': 'Brita',
      'metal': 'Vergalhão de aço',
      'steel': 'Vergalhão de aço',
      'iron': 'Vergalhão de aço',
      'wire': 'Fio elétrico',
      'cable': 'Fio elétrico',
      'pipe': 'Cano PVC',
      'plumbing': 'Cano PVC',
      'tile': 'Piso cerâmico',
      'flooring': 'Piso cerâmico',
      'roof': 'Telha',
      'paint': 'Tinta',
      'door': 'Porta',
      'window': 'Janela',
      'glass': 'Vidro',
      'ladder': 'Escada',
      'scaffolding': 'Andaime',
    };
    final rotulos = [
      for (final r in entrada['rotulos'] as List)
        if ((r[1] as num) >= 0.45) (r[0] as String, (r[1] as num).toDouble()),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    for (final (rotulo, _) in rotulos) {
      final m = mapa[rotulo.toLowerCase()];
      if (m != null) return {'material': m};
    }
    return {'material': null};
  }

  // ---------------------------------------------------------------- apoio

  /// Hipóteses do reconhecedor como o app as recebe: a principal (a
  /// transcrição) primeiro, seguida das alternativas. Alguns casos repetem
  /// a principal no começo da lista, com a confiança dela; nos outros a
  /// confiança da principal é desconhecida (0).
  static List<(String, double)> _hipoteses(Map<String, dynamic> entrada) {
    final principal = entrada['transcricao'] as String;
    final alternativas = [
      for (final a in (entrada['alternativas'] as List?) ?? const [])
        (a[0] as String, (a[1] as num).toDouble()),
    ];
    if (alternativas.isNotEmpty && alternativas.first.$1 == principal) {
      return alternativas;
    }
    return [(principal, 0), ...alternativas];
  }

  /// Texto corrido como o `RecognizedText.text` do ML Kit: blocos na ordem
  /// em que vieram, linhas de cada bloco separadas por quebra de linha.
  static String textoOcr(Map<String, dynamic> entrada) {
    final texto = entrada['texto'];
    if (texto is String) return texto;
    final blocos = entrada['blocos'] as List? ?? const [];
    return [
      for (final b in blocos)
        [for (final l in (b['linhas'] as List)) l['t'] as String].join('\n'),
    ].join('\n');
  }

  static PaletaObra _paleta(Map<String, dynamic>? p) {
    if (p == null) return const PaletaObra();
    double v(String k) => (p[k] as num?)?.toDouble() ?? 0;
    return PaletaObra(
      terra: v('terra'),
      tijolo: v('tijolo'),
      concreto: v('concreto'),
      claro: v('claro'),
      vegetacao: v('vegetacao'),
      ceuAzul: v('ceuAzul'),
      ceuCinza: v('ceuCinza'),
    );
  }

  static String? _data(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
}
