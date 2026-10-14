import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/constants/app_constants.dart';
import 'package:obra_facil/services/ia/material_vision_service.dart';

List<String> _materiais(List<RotuloFoto> rotulos, [String texto = '']) => [
      for (final m in MaterialVisionService.interpretar(rotulos, texto: texto))
        m.material,
    ];

void main() {
  group('Material pelo texto da embalagem', () {
    test('saco de cimento é reconhecido pelo que está impresso', () {
      final m = _materiais(
        const [RotuloFoto('Bag', 0.81), RotuloFoto('Paper', 0.62)],
        'Votoran\nCIMENTO PORTLAND\nCP II-F-32\n50 kg',
      );
      expect(m.first, 'Cimento');
    });

    test('a marca sozinha já identifica o cimento', () {
      expect(_materiais(const [], 'Itambé\n50kg').first, 'Cimento');
    });

    test('o código CP sem a palavra cimento também vale', () {
      expect(_materiais(const [], 'CP V-ARI\nSaco 40 kg').first, 'Cimento');
    });

    test('lata de tinta não vira vergalhão por ser de metal', () {
      final m = _materiais(
        const [RotuloFoto('Metal', 0.86), RotuloFoto('Tin', 0.61)],
        'Suvinil\nTINTA ACRÍLICA\nFosco Completo\n18L',
      );
      expect(m.first, 'Tinta');
      expect(m, isNot(contains('Vergalhão de aço')));
    });

    test('texto legível que não fala de aço também desmente o "Metal"', () {
      // OCR pegou só o acabamento da lata, não o nome do produto.
      final m = _materiais(
        const [RotuloFoto('Metal', 0.86)],
        'Fosco completo\n18 litros',
      );
      expect(m, isNot(contains('Vergalhão de aço')));
    });

    test('sem texto nenhum, metal continua sendo vergalhão', () {
      expect(
        _materiais(const [RotuloFoto('Metal', 0.90)]),
        ['Vergalhão de aço'],
      );
    });

    test('caixa de porcelanato é piso, mesmo citando a argamassa', () {
      final m = _materiais(
        const [RotuloFoto('Box', 0.72), RotuloFoto('Cardboard', 0.60)],
        'Eliane\nPORCELANATO ESMALTADO 60x60\nPEI 4\n'
        'Assentar com argamassa colante AC-II',
      );
      expect(m.first, 'Piso cerâmico');
      expect(m, isNot(contains('Argamassa')));
    });

    test('argamassa que cita cimento na composição continua argamassa', () {
      final m = _materiais(
        const [RotuloFoto('Bag', 0.77)],
        'quartzolit\nARGAMASSA COLANTE AC-II\n'
        'Composição: cimento Portland, areia e aditivos',
      );
      expect(m.first, 'Argamassa');
      expect(m, isNot(contains('Cimento')));
      expect(m, isNot(contains('Areia')));
    });

    test('"Votorantim Cimentos" no saco de argamassa não vira cimento', () {
      // "X Cimentos" é o nome da empresa, impresso também na argamassa.
      final m = _materiais(
        const [],
        'Votorantim Cimentos\nvotomassa\nArgamassa AC I\nUso interno\n20kg',
      );
      expect(m.first, 'Argamassa');
      expect(m, isNot(contains('Cimento')));
    });

    test('cimento que indica o uso em argamassa continua cimento', () {
      final m = _materiais(
        const [],
        'CIMENTO PORTLAND CP II-E-32\nIdeal para concreto, argamassa e reboco',
      );
      expect(m.first, 'Cimento');
      expect(m, isNot(contains('Argamassa')));
    });

    test('lista na linha de baixo do "Indicado para:" é só citação', () {
      // O OCR devolve cada linha impressa separada: o cabeçalho fica numa
      // linha e a lista de superfícies nas seguintes.
      final m = _materiais(
        const [],
        'Suvinil\nSelador Acrílico\nIndicado para:\n'
        'reboco, concreto, blocos de concreto,\ntelhas de fibrocimento\n3,6 L',
      );
      expect(m.first, 'Tinta');
      expect(m, isNot(contains('Bloco de concreto')));
      expect(m, isNot(contains('Telha')));
    });

    test('usos um por linha no saco de cimento não viram o produto', () {
      final m = _materiais(
        const [],
        'Votoran\nCP II-F-32\nIndicado para:\nArgamassas\nConcretos\n50 kg',
      );
      expect(m.first, 'Cimento');
      expect(m, isNot(contains('Argamassa')));
    });

    test('lista que segue depois da vírgula na outra linha é citação', () {
      final m = _materiais(
        const [],
        'CIMENTO PORTLAND CP II-E-32\nIdeal para concreto, reboco,\n'
        'argamassas e contrapisos',
      );
      expect(m.first, 'Cimento');
      expect(m, isNot(contains('Argamassa')));
    });

    test('a lista de usos acaba na linha da quantidade', () {
      // O nome do produto impresso depois da lista continua sendo o nome.
      final m = _materiais(
        const [],
        'Indicado para:\nparedes internas\n18 L\nTINTA ACRÍLICA',
      );
      expect(m.first, 'Tinta');
    });

    test('cabo com isolação de PVC não vira cano', () {
      final m = _materiais(
        const [RotuloFoto('Cable', 0.70)],
        'SIL\nCABO FLEXÍVEL 2,5 mm²\n450/750V\nIsolação PVC 70°C',
      );
      expect(m.first, 'Fio elétrico');
      expect(m, isNot(contains('Cano PVC')));
    });

    test('tubo de esgoto é cano PVC', () {
      expect(
          _materiais(const [], 'TIGRE\nTUBO ESGOTO 100mm').first, 'Cano PVC');
    });

    test('marca que vende vários produtos não prova o material sozinha', () {
      // Eternit e Tigre vendem caixa d'água; Belgo vende arame e prego.
      expect(
        _materiais(const [], "ETERNIT\nCaixa d'água\n1000 litros\nPolietileno"),
        isNot(contains('Telha')),
      );
      expect(
        _materiais(const [], "TIGRE\nCaixa d'água\n500 L"),
        isNot(contains('Cano PVC')),
      );
      expect(
        _materiais(
          const [RotuloFoto('Metal', 0.70)],
          'BELGO\nArame recozido\nBWG 18\n1 kg',
        ),
        isNot(contains('Vergalhão de aço')),
      );
    });

    test('telha com a marca e o tipo gravados continua telha', () {
      final m = _materiais(
        const [RotuloFoto('Roof', 0.58)],
        'BRASILIT\nONDULADA 6mm',
      );
      expect(m.first, 'Telha');
    });

    test('"tubo" sozinho é a embalagem, não o cano', () {
      expect(
        _materiais(const [], 'Selante PU 40\nCinza\nTubo 400g'),
        isNot(contains('Cano PVC')),
      );
    });

    test('etiqueta CA-50 confirma o vergalhão', () {
      final m = _materiais(
        const [RotuloFoto('Metal', 0.70)],
        'GERDAU CA-50 10,0mm 12m',
      );
      expect(m.first, 'Vergalhão de aço');
    });

    test('cal hidratada não vira argamassa por citar o uso', () {
      final m = _materiais(
        const [],
        'CAL HIDRATADA CH-III 20kg\nPara argamassas de assentamento',
      );
      expect(m.first, 'Cal');
      expect(m, isNot(contains('Argamassa')));
    });

    test('telha de fibrocimento não é cimento', () {
      final m = _materiais(
        const [RotuloFoto('Roof', 0.58)],
        'BRASILIT\nTELHA ONDULADA DE FIBROCIMENTO 6mm',
      );
      expect(m.first, 'Telha');
      expect(m, isNot(contains('Cimento')));
    });

    test('pedaço de palavra não conta', () {
      // "calçadão" não é cal, "pisoteio" não é piso.
      expect(
          _materiais(const [], 'Calçadão Central\nPisoteio proibido'), isEmpty);
    });

    test('caixa e acento não importam', () {
      expect(_materiais(const [], 'vergalhão 8mm').first, 'Vergalhão de aço');
      expect(_materiais(const [], 'ARGAMASSA').first, 'Argamassa');
    });

    test('dígito lido no lugar da letra é corrigido', () {
      expect(_materiais(const [], 'CIMENT0 P0RTLAND').first, 'Cimento');
    });

    test('palavra que só desempata não lista material sozinha', () {
      expect(_materiais(const [], 'Indústria Nacional\nLote 4471'), isEmpty);
    });

    test('a leitura cita de onde veio', () {
      final m = MaterialVisionService.interpretar(
        const [],
        texto: 'TINTA ESMALTE',
      );
      expect(m.first.labelOriginal, contains('embalagem'));
      expect(m.first.confianca, lessThan(1));
    });
  });

  group('Material pelos rótulos do classificador', () {
    test('sem texto, os rótulos funcionam como antes', () {
      expect(_materiais(const [RotuloFoto('Brick', 0.90)]), ['Tijolo']);
      expect(
        _materiais(const [RotuloFoto('Wood', 0.80), RotuloFoto('Plank', 0.6)]),
        ['Madeira'],
      );
    });

    test('rótulo abaixo da confiança mínima é ignorado', () {
      expect(_materiais(const [RotuloFoto('Brick', 0.30)]), isEmpty);
    });

    test('"Concrete" junto de tijolo é bloco de concreto', () {
      final m = _materiais(
        const [RotuloFoto('Concrete', 0.76), RotuloFoto('Brick', 0.70)],
      );
      expect(m, contains('Bloco de concreto'));
      expect(m, isNot(contains('Tijolo')));
    });

    test('rótulo específico de outro material cala o genérico', () {
      // A lata de tinta: "Paint" diz o que é, "Metal" é só a embalagem.
      expect(
        _materiais(const [RotuloFoto('Metal', 0.84), RotuloFoto('Paint', 0.7)]),
        ['Tinta'],
      );
    });

    test('texto vem antes do rótulo na ordem', () {
      final m = _materiais(const [RotuloFoto('Wood', 0.82)], 'TINTA');
      expect(m, ['Tinta', 'Madeira']);
    });

    test('rótulo que não é material não inventa nada', () {
      expect(
        _materiais(const [RotuloFoto('Selfie', 0.9), RotuloFoto('Glass', 0.8)]),
        isEmpty,
      );
    });

    test('todo material devolvido existe no catálogo do app', () {
      final entradas = <(List<RotuloFoto>, String)>[
        (
          const [
            RotuloFoto('Glass', 0.9),
            RotuloFoto('Ladder', 0.8),
            RotuloFoto('Scaffolding', 0.7),
            RotuloFoto('Concrete', 0.7),
            RotuloFoto('Roof', 0.7),
            RotuloFoto('Rock', 0.6),
          ],
          '',
        ),
        (const [], 'TELHA CERÂMICA\nBLOCO DE CONCRETO\nPORTA E JANELA'),
      ];
      for (final (rotulos, texto) in entradas) {
        for (final m in _materiais(rotulos, texto)) {
          expect(AppConstants.materiaisComuns, contains(m));
        }
      }
    });
  });
}
