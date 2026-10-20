// O que a CenaMaquete faz com o modelo carregado (achar os nós, trocar os
// materiais de tema e do fantasma, mostrar/esconder/escalar as peças),
// sobre `Node`s e materiais de verdade do flutter_scene. Sem GPU não dá
// para carregar o glb nem criar a `Scene`, mas nós, malhas (com uma
// geometria vazia) e materiais existem sem ela: o modelo aqui é montado à
// mão com os mesmos nomes e a mesma árvore do maquete.glb.

import 'package:flutter_scene/scene.dart' as fs;
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/maquete/cena_maquete.dart';
import 'package:obra_facil/design/maquete/plano_maquete.dart';
// ignore: depend_on_referenced_packages
import 'package:vector_math/vector_math.dart' as vm;

/// Os materiais do "molde": no app, o `loadScene` dá a toda instância do
/// mesmo glb os mesmos objetos de material.
class _Molde {
  final base = fs.PhysicallyBasedMaterial()
    ..name = 'base'
    ..baseColorFactor = vm.Vector4(0.89, 0.89, 0.86, 1)
    ..roughnessFactor = 0.9;
  final grade = fs.PhysicallyBasedMaterial()..name = 'grade';
  final cota = fs.PhysicallyBasedMaterial()..name = 'cota';
  final concreto = fs.PhysicallyBasedMaterial()..name = 'concreto';
  final fantasma = fs.UnlitMaterial()
    ..name = 'fantasma'
    ..doubleSided = true
    ..depthLayer = 1;
}

fs.Node _malha(String nome, List<fs.Material> materiais) => fs.Node(
      name: nome,
      mesh: fs.Mesh.primitives(primitives: [
        for (final m in materiais) fs.MeshPrimitive(fs.UnskinnedGeometry(), m),
      ]),
    );

/// A árvore do maquete.glb: maquete > base, cotas, fase_XX > peças,
/// fantasma_fase_XX (06 e 08 sem malha).
fs.Node _modelo(_Molde molde, {Set<String> sem = const {}}) {
  final raiz = fs.Node(name: NosMaquete.raiz)
    ..add(_malha(NosMaquete.base, [molde.base, molde.grade]))
    ..add(_malha(NosMaquete.cotas, [molde.cota]));
  for (var f = 0; f < 10; f++) {
    final fase = fs.Node(name: 'fase_${f.toString().padLeft(2, '0')}');
    for (final etapa in PlanoMaquete.etapasPorFase[f]) {
      if (!sem.contains(etapa.no)) {
        fase.add(_malha(etapa.no, [molde.concreto]));
      }
    }
    raiz.add(fase);
    final nome = NosMaquete.fantasma(f);
    if (sem.contains(nome)) continue;
    raiz.add(f == 6 || f == 8
        ? fs.Node(name: nome)
        : _malha(nome, [molde.fantasma]));
  }
  return raiz;
}

List<fs.MeshPrimitive> _primitivas(fs.Node raiz, String nome) =>
    raiz.getChildByName(nome)!.mesh!.primitives;

vm.Vector4 _linear(TemaMaquete tema, String material) {
  final l = TemaMaquete.linear(tema.corDoMaterial(material)!);
  return vm.Vector4(l[0], l[1], l[2], 1);
}

void _perto(vm.Vector4 a, vm.Vector4 b) {
  for (var i = 0; i < 4; i++) {
    expect(a[i], closeTo(b[i], 1e-9));
  }
}

void main() {
  test('acha todo nó do plano; nó ausente lança com o nome', () {
    final pecas = PecasMaquete.doModelo(
      _modelo(_Molde()),
      tema: TemaMaquete.claro,
    );
    for (final nome in PlanoMaquete.todosOsNos) {
      expect(pecas.estadoDoNo(nome), isNotNull, reason: nome);
    }
    expect(
      () => PecasMaquete.doModelo(
        _modelo(_Molde(), sem: {'estrutura_vigas', 'fantasma_fase_06'}),
        tema: TemaMaquete.claro,
      ),
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'mensagem',
        allOf(contains('estrutura_vigas'), contains('fantasma_fase_06')),
      )),
    );
  });

  test('fantasma: material desta instância, sem luz, sem cor de vértice e '
      'sem sombra', () {
    final molde = _Molde();
    final raiz = _modelo(molde);
    final pecas = PecasMaquete.doModelo(raiz, tema: TemaMaquete.claro);
    for (final f in [0, 1, 2, 3, 4, 5, 7, 9]) {
      final nome = NosMaquete.fantasma(f);
      final p = _primitivas(raiz, nome).single;
      expect(p.material, same(pecas.fantasma), reason: nome);
      expect(p.castsShadow, isFalse);
      expect(raiz.getChildByName(nome)!.shadowCastingMode,
          fs.ShadowCastingMode.off);
    }
    expect(pecas.fantasma.vertexColorWeight, 0);
    expect(pecas.fantasma.doubleSided, isTrue);
    expect(pecas.fantasma.depthLayer, 1, reason: 'herda do original');
    _perto(
      pecas.fantasma.baseColorFactor,
      vm.Vector4(
        TemaMaquete.claro.fantasmaNaCena[0],
        TemaMaquete.claro.fantasmaNaCena[1],
        TemaMaquete.claro.fantasmaNaCena[2],
        1,
      ),
    );
    // As peças de verdade continuam projetando sombra.
    expect(_primitivas(raiz, 'estrutura_pilares').single.castsShadow, isTrue);
  });

  test('materiais de tema: cópias desta instância; o molde compartilhado e '
      'os outros materiais não mudam', () {
    final molde = _Molde();
    final corDoMolde = molde.base.baseColorFactor.clone();
    final raizA = _modelo(molde);
    final raizB = _modelo(molde);
    final a = PecasMaquete.doModelo(raizA, tema: TemaMaquete.claro);
    final b = PecasMaquete.doModelo(raizB, tema: TemaMaquete.escuro);

    final baseA = _primitivas(raizA, NosMaquete.base);
    final baseB = _primitivas(raizB, NosMaquete.base);
    expect(baseA[0].material, same(a.materialDeTema('base')));
    expect(baseA[1].material, same(a.materialDeTema('grade')));
    expect(baseB[0].material, same(b.materialDeTema('base')));
    expect(baseA[0].material, isNot(same(baseB[0].material)));
    expect(baseA[0].material, isNot(same(molde.base)));
    _perto(a.materialDeTema('base')!.baseColorFactor,
        _linear(TemaMaquete.claro, 'base'));
    _perto(b.materialDeTema('base')!.baseColorFactor,
        _linear(TemaMaquete.escuro, 'base'));
    _perto(a.materialDeTema('cota')!.baseColorFactor,
        _linear(TemaMaquete.claro, 'cota'));
    expect(a.materialDeTema('base')!.roughnessFactor, 0.9);
    // O molde fica como veio do glb.
    _perto(molde.base.baseColorFactor, corDoMolde);
    expect(a.fantasma, isNot(same(b.fantasma)));
    // Material que não é de tema não é trocado.
    expect(_primitivas(raizA, 'estrutura_laje').single.material,
        same(molde.concreto));
  });

  test('trocar o tema troca as cores dos materiais da instância', () {
    final raiz = _modelo(_Molde());
    final pecas = PecasMaquete.doModelo(raiz, tema: TemaMaquete.claro);
    final base = pecas.materialDeTema('base');
    pecas.aplicarTema(TemaMaquete.escuro);
    expect(pecas.materialDeTema('base'), same(base));
    _perto(base!.baseColorFactor, _linear(TemaMaquete.escuro, 'base'));
    final f = TemaMaquete.escuro.fantasmaNaCena;
    _perto(pecas.fantasma.baseColorFactor, vm.Vector4(f[0], f[1], f[2], 1));
  });

  test('aplicar mostra, esconde e escala os nós de verdade', () {
    final raiz = _modelo(_Molde());
    final pecas = PecasMaquete.doModelo(raiz, tema: TemaMaquete.claro);
    fs.Node no(String nome) => raiz.getChildByName(nome)!;

    // Fundação pronta, estrutura em 20% (pilares subindo), alvenaria na
    // metade.
    final plano = PlanoMaquete.calcular([1, 0.2, 0.5, 0, 0, 0, 0, 0, 0, 0]);
    expect(pecas.aplicar(plano), isTrue);
    expect(no('fundacao_radier').visible, isTrue);
    expect(no(NosMaquete.fantasma(0)).visible, isFalse);
    expect(no(NosMaquete.fantasma(1)).visible, isTrue);
    final pilares = plano.pecas['estrutura_pilares']!;
    expect(pilares.escalaY, inExclusiveRange(0, 1));
    expect(no('estrutura_pilares').visible, isTrue);
    expect(no('estrutura_pilares').scale.y, closeTo(pilares.escalaY, 1e-6));
    expect(no('estrutura_pilares').scale.x, closeTo(1, 1e-6));
    expect(no('estrutura_vigas').visible, isFalse);
    for (var k = 0; k < 15; k++) {
      expect(no(NosMaquete.fiada(k)).visible, k < 7, reason: 'fiada $k');
    }
    expect(no('cobertura_telhas').visible, isFalse);

    // O mesmo plano de novo: nada a escrever.
    expect(pecas.aplicar(plano), isFalse);

    // Escondida no meio do crescimento e depois pronta: volta à escala 1.
    pecas.aplicar(PlanoMaquete.calcular([1, 0, 0.5]));
    expect(no('estrutura_pilares').visible, isFalse);
    pecas.aplicar(PlanoMaquete.calcular([1, 1, 0.5]));
    expect(no('estrutura_pilares').visible, isTrue);
    final s = no('estrutura_pilares').scale;
    expect([s.x, s.y, s.z], [1, 1, 1].map((v) => closeTo(v, 1e-6)).toList());
    expect(pecas.estadoDoNo('estrutura_pilares'), (true, 1.0, 1.0, 1.0));
  });
}
