import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'adaptadores.dart';

/// Avaliação das IAs contra o conjunto de casos de `casos/`.
///
/// Não é um teste de "passa ou falha" caso a caso: mede o acerto de cada
/// campo, imprime a tabela e, com `AVALIACAO_SALVAR=<rótulo>`, grava
/// `resultados/<rótulo>.json` para comparar versões. O que ele trava é a
/// regressão: a acurácia não pode cair abaixo do piso registrado em
/// `resultados/piso.json` (quando existir).
void main() {
  final conjuntos = <_Conjunto>[
    _Conjunto('voz_lancamento', Adaptadores.vozLancamento, {
      'valor': _numero,
      'categoria': _igual,
      'fornecedor': _texto,
      'data': _igual,
      'itens': _itens,
    }),
    _Conjunto('voz_diario', Adaptadores.vozDiario, {
      'clima': _igual,
      'pessoas': _numero,
      'fase': _igual,
      'data': _igual,
    }),
    _Conjunto('ocr_notas', Adaptadores.ocrNota, {
      'fornecedor': _texto,
      'cnpj': _igual,
      'total': _numero,
      'data': _igual,
    }),
    _Conjunto('foto_diario', Adaptadores.fotoDiario, {
      'fase': _igual,
      'clima': _igual,
    }),
    _Conjunto('material', Adaptadores.material, {
      'material': _texto,
    }),
  ];

  test('avaliação das IAs (acerto por campo)', () {
    final resultado = <String, dynamic>{};
    final linhas = <String>[];

    for (final c in conjuntos) {
      final arquivo = File('test/avaliacao/casos/${c.nome}.json');
      if (!arquivo.existsSync()) continue;
      final casos =
          (jsonDecode(arquivo.readAsStringSync()) as List).cast<Map>();

      // Placar geral e por partição: "dev" é a metade usada para estudar
      // os erros; "teste" fica de fora e mede se a melhora generaliza.
      final placares = <String, Map<String, _Placar>>{
        'todos': {},
        'dev': {},
        'teste': {},
      };
      final falhas = <Map<String, Object?>>[];
      final perfeitos = <String, int>{'todos': 0, 'dev': 0, 'teste': 0};
      final totais = <String, int>{'todos': 0, 'dev': 0, 'teste': 0};

      for (final caso in casos) {
        final particao = (caso['particao'] as String?) ?? 'dev';
        // Cada resultado conta no placar geral e no da partição do caso.
        void registrar(String campo, _Resultado r) {
          for (final g in [placares['todos']!, placares[particao]!]) {
            g.putIfAbsent(campo, _Placar.new).registrar(r);
          }
        }

        final esperado = (caso['esperado'] as Map).cast<String, dynamic>();
        final entrada = (caso['entrada'] as Map).cast<String, dynamic>();
        Map<String, Object?> obtido;
        try {
          obtido = c.adaptador(entrada);
        } catch (e) {
          obtido = {'_erro': '$e'};
        }

        var perfeito = true;
        final campos = {...c.campos.keys, 'materiais'};
        for (final campo in campos) {
          if (campo == 'materiais') {
            // Foto: lista de materiais que precisam (ou não) aparecer.
            final contem = (esperado['materiais_contem'] as List?) ?? const [];
            final naoContem =
                (esperado['materiais_nao_contem'] as List?) ?? const [];
            if (contem.isEmpty && naoContem.isEmpty) continue;
            final vistos = ((obtido['materiais'] as List?) ?? const [])
                .map((m) => _normalizar('$m'))
                .toSet();
            final ok =
                contem.every((m) => vistos.contains(_normalizar('$m'))) &&
                    naoContem.every((m) => !vistos.contains(_normalizar('$m')));
            registrar('materiais', ok ? _Resultado.acerto : _Resultado.errado);
            if (!ok) {
              perfeito = false;
              falhas.add({
                'id': caso['id'],
                'particao': particao,
                'campo': 'materiais',
                'esperado': {'contem': contem, 'nao_contem': naoContem},
                'obtido': obtido['materiais'],
              });
            }
            continue;
          }
          if (!esperado.containsKey(campo)) continue;
          final comparar = c.campos[campo]!;
          final e = esperado[campo];
          final o = obtido[campo];
          final vazioO = o == null || (o is List && o.isEmpty);
          final vazioE = e == null || (e is List && e.isEmpty);
          final r = switch ((vazioE, vazioO)) {
            (true, true) => _Resultado.acerto,
            (false, true) => _Resultado.omitido,
            (true, false) => _Resultado.inventado,
            _ => comparar(e, o) ? _Resultado.acerto : _Resultado.errado,
          };
          registrar(campo, r);
          if (r != _Resultado.acerto) {
            perfeito = false;
            falhas.add({
              'id': caso['id'],
              'particao': particao,
              'campo': campo,
              'esperado': e,
              'obtido': o,
            });
          }
        }
        for (final g in ['todos', particao]) {
          totais[g] = totais[g]! + 1;
          if (perfeito) perfeitos[g] = perfeitos[g]! + 1;
        }
      }

      final placar = placares['todos']!;
      resultado[c.nome] = {
        'casos': casos.length,
        'casos_perfeitos': perfeitos['todos'],
        'campos': {for (final e in placar.entries) e.key: e.value.toJson()},
        'por_particao': {
          for (final g in ['dev', 'teste'])
            g: {
              'casos': totais[g],
              'casos_perfeitos': perfeitos[g],
              'campos': {
                for (final e in placares[g]!.entries) e.key: e.value.toJson(),
              },
            },
        },
        'falhas': falhas,
      };
      linhas.add('\n${c.nome} — ${casos.length} casos, '
          '${perfeitos['todos']} perfeitos '
          '(${_pct(perfeitos['todos']!, casos.length)}); '
          'só teste: ${perfeitos['teste']}/${totais['teste']}');
      linhas.add('  campo        acerto  (teste)  errado omitido inventado');
      for (final e in placar.entries) {
        final p = e.value;
        final t = placares['teste']![e.key];
        final pctTeste = t == null ? '—' : _pct(t.acertos, t.avaliados);
        linhas.add('  ${e.key.padRight(11)} '
            '${_pct(p.acertos, p.avaliados).padLeft(6)} '
            '${'($pctTeste)'.padLeft(8)} '
            '${'${p.errados}'.padLeft(7)} ${'${p.omitidos}'.padLeft(7)} '
            '${'${p.inventados}'.padLeft(9)}   (n=${p.avaliados})');
      }
    }

    // ignore: avoid_print
    print('Avaliação das IAs${linhas.join('\n')}');

    final rotulo = Platform.environment['AVALIACAO_SALVAR'];
    if (rotulo != null && rotulo.isNotEmpty) {
      final saida = File('test/avaliacao/resultados/$rotulo.json');
      saida.parent.createSync(recursive: true);
      saida.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(resultado));
    }

    // Trava de regressão: nenhum campo pode ficar abaixo do piso gravado.
    final piso = File('test/avaliacao/resultados/piso.json');
    if (piso.existsSync()) {
      final pisos = jsonDecode(piso.readAsStringSync()) as Map;
      for (final conjunto in pisos.entries) {
        for (final campo in (conjunto.value as Map).entries) {
          final medido = resultado[conjunto.key]?['campos']?[campo.key];
          if (medido == null) continue;
          expect(
            medido['acuracia'] as num,
            greaterThanOrEqualTo(campo.value as num),
            reason: 'Acurácia de ${conjunto.key}.${campo.key} caiu abaixo '
                'do piso — veja as falhas impressas acima.',
          );
        }
      }
    }
  });
}

typedef _Comparador = bool Function(Object? esperado, Object? obtido);

class _Conjunto {
  final String nome;
  final Map<String, Object?> Function(Map<String, dynamic>) adaptador;
  final Map<String, _Comparador> campos;

  _Conjunto(this.nome, this.adaptador, this.campos);
}

enum _Resultado { acerto, errado, omitido, inventado }

class _Placar {
  int avaliados = 0;
  int acertos = 0;
  int errados = 0;
  int omitidos = 0;
  int inventados = 0;

  void registrar(_Resultado r) {
    avaliados++;
    switch (r) {
      case _Resultado.acerto:
        acertos++;
      case _Resultado.errado:
        errados++;
      case _Resultado.omitido:
        omitidos++;
      case _Resultado.inventado:
        inventados++;
    }
  }

  Map<String, Object> toJson() => {
        'avaliados': avaliados,
        'acertos': acertos,
        'errados': errados,
        'omitidos': omitidos,
        'inventados': inventados,
        'acuracia': avaliados == 0
            ? 0
            : double.parse((acertos / avaliados).toStringAsFixed(4)),
      };
}

bool _igual(Object? e, Object? o) => '$e' == '$o';

bool _numero(Object? e, Object? o) =>
    e is num && o is num && (e - o).abs() < 0.01;

bool _texto(Object? e, Object? o) => _normalizar('$e') == _normalizar('$o');

/// Itens: o conjunto (material, quantidade, unidade) tem de bater inteiro.
bool _itens(Object? e, Object? o) {
  String chave(Object? i) {
    final m = (i as Map);
    return '${_normalizar('${m['material']}')}|'
        '${(m['quantidade'] as num).toDouble()}|${m['unidade']}';
  }

  final esperados = (e as List).map(chave).toSet();
  final obtidos = (o as List).map(chave).toSet();
  return esperados.length == obtidos.length && esperados.containsAll(obtidos);
}

String _normalizar(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  final buffer = StringBuffer();
  for (final ch in s.toLowerCase().trim().split('')) {
    final i = de.indexOf(ch);
    buffer.write(i == -1 ? ch : para[i]);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

String _pct(int a, int total) =>
    total == 0 ? '—' : '${(100 * a / total).toStringAsFixed(0)}%';
