import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:obra_facil/services/ia/perguntas_obra_service.dart';
import 'package:obra_facil/utils/formatters.dart';

import 'obra_exemplo.dart';

/// Avaliação do assistente "Perguntar sobre a obra" contra
/// `casos/perguntas.json`, com a obra de exemplo de `obra_exemplo.dart`.
///
/// Mede três campos por pergunta:
/// - `intencao`: o assunto que a resposta trata (`RespostaObra.intencao`);
/// - `fatos`: os números e nomes que precisam aparecer no texto;
/// - `sem_dinheiro`: no modo cliente, nenhum valor em dinheiro no texto.
///
/// ```bash
/// flutter test test/avaliacao/perguntas_avaliacao_test.dart
/// AVALIACAO_SALVAR=depois flutter test test/avaliacao/perguntas_avaliacao_test.dart
/// AVALIACAO_FALHAS=todas flutter test test/avaliacao/perguntas_avaliacao_test.dart
/// ```
///
/// Por padrão só as falhas da metade **dev** são impressas: a metade teste
/// fica sem olhar, para medir se a correção generaliza.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  test('avaliação do assistente de perguntas', () {
    final casos = (jsonDecode(
            File('test/avaliacao/casos/perguntas.json').readAsStringSync())
        as List)
        .cast<Map<String, dynamic>>();

    final completo = obraExemplo();
    final doCliente = obraExemplo(cliente: true);

    const grupos = ['todos', 'dev', 'teste', 'cliente', 'equipe'];
    final placares = {for (final g in grupos) g: <String, _Placar>{}};
    final perfeitos = {for (final g in grupos) g: 0};
    final totais = {for (final g in grupos) g: 0};
    final porTipo = <String, List<int>>{}; // tipo → [perfeitos, total]
    final falhas = <Map<String, Object?>>[];

    for (final caso in casos) {
      final particao = caso['particao'] as String? ?? 'dev';
      final modo = caso['modo'] as String? ?? 'equipe';
      final entrada = caso['entrada'] as Map<String, dynamic>;
      final esperado = caso['esperado'] as Map<String, dynamic>;
      final cliente = entrada['modo_cliente'] == true;
      final dados =
          cliente && entrada['dados'] != 'completo' ? doCliente : completo;

      String texto;
      Set<String> intencoes;
      try {
        final r = PerguntasObraService.responder(
          entrada['pergunta'] as String,
          dados,
          agora: agoraExemplo,
          modoCliente: cliente,
        );
        texto = r.texto;
        intencoes = _intencoes(r.intencao);
      } catch (e) {
        texto = '<erro: $e>';
        intencoes = {'<erro>'};
      }
      final norm = _normalizar(texto);

      final resultados = <String, _Resultado>{};
      final motivos = <String, Object?>{};

      // ── intenção ──
      if (esperado.containsKey('intencao') ||
          esperado.containsKey('intencao_ou')) {
        final r = _compararIntencao(esperado, intencoes);
        resultados['intencao'] = r;
        if (r != _Resultado.acerto) {
          motivos['intencao'] = {
            'esperado': esperado['intencao'] ?? {'ou': esperado['intencao_ou']},
            'obtido': intencoes.join('+'),
          };
        }
      }

      // ── fatos ──
      final contem = ((esperado['contem'] as List?) ?? const []).cast<String>();
      final algum = ((esperado['contem_algum'] as List?) ?? const [])
          .map((g) => (g as List).cast<String>())
          .toList();
      if (contem.isNotEmpty || algum.isNotEmpty) {
        final faltam = [
          for (final f in contem)
            if (!_temFato(norm, f)) f,
          for (final g in algum)
            if (!g.any((f) => _temFato(norm, f))) 'um de ${g.join(' | ')}',
        ];
        final r = faltam.isEmpty
            ? _Resultado.acerto
            : intencoes.length == 1 && intencoes.first == 'nao_sei'
                ? _Resultado.omitido
                : _Resultado.errado;
        resultados['fatos'] = r;
        if (r != _Resultado.acerto) motivos['fatos'] = {'faltam': faltam};
      }

      // ── o que não pode aparecer ──
      final proibidos =
          ((esperado['nao_contem'] as List?) ?? const []).cast<String>();
      if (esperado['sem_dinheiro'] == true || proibidos.isNotEmpty) {
        final vazou = [
          if (esperado['sem_dinheiro'] == true) ..._dinheiroNoTexto(norm),
          for (final p in proibidos)
            if (_temFato(norm, p)) p,
        ];
        resultados['sem_dinheiro'] =
            vazou.isEmpty ? _Resultado.acerto : _Resultado.errado;
        if (vazou.isNotEmpty) motivos['sem_dinheiro'] = {'vazou': vazou};
      }

      final perfeito = resultados.values.every((r) => r == _Resultado.acerto);
      for (final g in ['todos', particao, modo]) {
        for (final e in resultados.entries) {
          placares[g]!.putIfAbsent(e.key, _Placar.new).registrar(e.value);
        }
        totais[g] = totais[g]! + 1;
        if (perfeito) perfeitos[g] = perfeitos[g]! + 1;
      }
      final tipos = ((caso['tipos'] as List?) ?? const []).cast<String>();
      for (final t in [...tipos, if (cliente) 'modo_cliente']) {
        final p = porTipo.putIfAbsent(t, () => [0, 0]);
        if (perfeito) p[0]++;
        p[1]++;
      }
      if (!perfeito) {
        falhas.add({
          'id': caso['id'],
          'particao': particao,
          'modo': modo,
          'pergunta': entrada['pergunta'],
          ...motivos,
          'resposta': texto,
        });
      }
    }

    // ── tabela ──
    final linhas = <String>[
      'Assistente de perguntas — ${casos.length} casos, '
          '${perfeitos['todos']} perfeitos '
          '(${_pct(perfeitos['todos']!, totais['todos']!)}); '
          'só teste: ${perfeitos['teste']}/${totais['teste']} '
          '(${_pct(perfeitos['teste']!, totais['teste']!)}); '
          'só cliente: ${perfeitos['cliente']}/${totais['cliente']} '
          '(${_pct(perfeitos['cliente']!, totais['cliente']!)})',
      '  campo          acerto  (teste) (cliente)  errado omitido inventado',
    ];
    for (final e in placares['todos']!.entries) {
      final p = e.value;
      String pctDe(String g) {
        final x = placares[g]![e.key];
        return x == null ? '—' : _pct(x.acertos, x.avaliados);
      }

      linhas.add('  ${e.key.padRight(13)} '
          '${_pct(p.acertos, p.avaliados).padLeft(6)} '
          '${'(${pctDe('teste')})'.padLeft(8)} '
          '${'(${pctDe('cliente')})'.padLeft(9)} '
          '${'${p.errados}'.padLeft(7)} ${'${p.omitidos}'.padLeft(7)} '
          '${'${p.inventados}'.padLeft(9)}   (n=${p.avaliados})');
    }
    linhas.add('  casos perfeitos por tipo de pergunta:');
    final tiposOrdenados = porTipo.keys.toList()..sort();
    for (final t in tiposOrdenados) {
      final p = porTipo[t]!;
      linhas.add('    ${t.padRight(16)} ${'${p[0]}/${p[1]}'.padLeft(7)} '
          '${_pct(p[0], p[1]).padLeft(5)}');
    }

    final mostrar = Platform.environment['AVALIACAO_FALHAS'] ?? 'dev';
    final visiveis = [
      for (final f in falhas)
        if (mostrar == 'todas' || (mostrar == 'dev' && f['particao'] == 'dev'))
          f,
    ];
    if (visiveis.isNotEmpty) {
      linhas.add('\n  falhas ($mostrar):');
      for (final f in visiveis) {
        final motivo = [
          for (final c in ['intencao', 'fatos', 'sem_dinheiro'])
            if (f[c] != null) '$c ${jsonEncode(f[c])}',
        ].join('; ');
        linhas.add('  · ${f['id']} [${f['modo']}] "${f['pergunta']}"\n'
            '      $motivo\n'
            '      → ${(f['resposta'] as String).replaceAll('\n', ' ⏎ ')}');
      }
    }
    // ignore: avoid_print
    print(linhas.join('\n'));

    // ── gravação ──
    Map<String, Object?> bloco(String g) => {
          'casos': totais[g],
          'casos_perfeitos': perfeitos[g],
          'campos': {
            for (final e in placares[g]!.entries) e.key: e.value.toJson(),
          },
        };
    final resultado = <String, Object?>{
      'perguntas': {
        ...bloco('todos'),
        'por_particao': {for (final g in ['dev', 'teste']) g: bloco(g)},
        'por_modo': {for (final g in ['equipe', 'cliente']) g: bloco(g)},
        'por_tipo': {
          for (final t in tiposOrdenados)
            t: {'casos': porTipo[t]![1], 'casos_perfeitos': porTipo[t]![0]},
        },
        'falhas': falhas,
      },
    };
    final rotulo = Platform.environment['AVALIACAO_SALVAR'];
    if (rotulo != null && rotulo.isNotEmpty) {
      final saida = File('test/avaliacao/resultados/perguntas-$rotulo.json');
      saida.parent.createSync(recursive: true);
      saida.writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(resultado)}\n');
    }

    // ── trava de regressão: o piso de `resultados/piso.json` ──
    final piso = File('test/avaliacao/resultados/piso.json');
    if (piso.existsSync()) {
      final pisos = (jsonDecode(piso.readAsStringSync()) as Map)['perguntas'];
      if (pisos is Map) {
        for (final campo in pisos.entries) {
          final medido = placares['todos']![campo.key];
          if (medido == null) continue;
          expect(
            medido.acuracia,
            greaterThanOrEqualTo(campo.value as num),
            reason: 'Acurácia de perguntas.${campo.key} caiu abaixo do piso '
                '— veja as falhas impressas acima.',
          );
        }
      }
    }
  });
}

/// "gasto+estoque" → {gasto, estoque}; nula vira um marcador de ausência.
Set<String> _intencoes(String? intencao) {
  if (intencao == null || intencao.trim().isEmpty) return {'<sem intencao>'};
  return intencao.split('+').map((s) => s.trim()).toSet();
}

/// `intencao` (texto ou lista: todas precisam ser tratadas) ou
/// `intencao_ou` (qualquer uma das alternativas serve).
_Resultado _compararIntencao(Map<String, dynamic> esperado, Set<String> o) {
  final naoSei = o.length == 1 && o.first == 'nao_sei';
  final alternativas = esperado['intencao_ou'];
  if (alternativas is List) {
    final alts = alternativas.cast<String>().toSet();
    if (alts.containsAll(o)) return _Resultado.acerto;
    return naoSei ? _Resultado.omitido : _Resultado.errado;
  }
  final bruto = esperado['intencao'];
  final e = bruto is List ? bruto.cast<String>().toSet() : {bruto as String};
  if (e.length == o.length && e.containsAll(o)) return _Resultado.acerto;
  if (naoSei) return _Resultado.omitido;
  if (e.length == 1 && e.first == 'nao_sei') return _Resultado.inventado;
  // Pergunta composta respondida pela metade: falta parte da resposta.
  if (e.length > 1 && o.every(e.contains)) return _Resultado.omitido;
  return _Resultado.errado;
}

/// Fato esperado no texto. `re:` é expressão regular (sobre o texto
/// normalizado); `R$ ...` aceita o valor por extenso ou compacto
/// (`R$ 102.715,00` ou `R$ 103 mil`); o resto é trecho de texto.
bool _temFato(String texto, String fato) {
  if (fato.startsWith('re:')) return RegExp(fato.substring(3)).hasMatch(texto);
  if (fato.startsWith(r'R$')) {
    final valor = Formatters.parseValor(fato);
    if (valor != null) {
      return texto.contains(_normalizar(Formatters.moeda(valor))) ||
          texto.contains(_normalizar(Formatters.moedaCompacta(valor)));
    }
  }
  return texto.contains(_normalizar(fato));
}

/// Trechos com cara de dinheiro: "R$", "1.234,56", "450,00", "reais",
/// "280 mil".
List<String> _dinheiroNoTexto(String texto) => [
      for (final m in RegExp(r'r\$|\b\d+(\.\d{3})*,\d{2}\b|\breais\b|'
              r'\b\d+(,\d+)? mil\b')
          .allMatches(texto))
        m.group(0)!,
    ];

String _normalizar(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  final buffer = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = de.indexOf(ch);
    buffer.write(i == -1 ? ch : para[i]);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[\s  ]+'), ' ')
      .trim();
}

enum _Resultado { acerto, errado, omitido, inventado }

class _Placar {
  int avaliados = 0;
  int acertos = 0;
  int errados = 0;
  int omitidos = 0;
  int inventados = 0;

  double get acuracia => avaliados == 0 ? 0 : acertos / avaliados;

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
        'acuracia': double.parse(acuracia.toStringAsFixed(4)),
      };
}

String _pct(int a, int total) =>
    total == 0 ? '—' : '${(100 * a / total).toStringAsFixed(0)}%';
