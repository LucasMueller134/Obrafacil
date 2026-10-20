import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart' as fs;
// O vector_math chega pelo flutter_scene (transitivo, travado no
// pubspec.lock) e é o tipo de Vector3/Vector4 da API dele; não é o
// vector_math_64 do Flutter.
// ignore: depend_on_referenced_packages
import 'package:vector_math/vector_math.dart' as vm;

import 'plano_maquete.dart';

/// O que a `MaqueteObra` usa da cena 3D. A implementação é a [CenaMaquete];
/// nos testes (sem Flutter GPU, onde nem `Scene()` pode ser criada) entra
/// um falso.
abstract interface class Cena3dMaquete {
  /// Troca as cores de tema (claro/escuro).
  void aplicarTema(TemaMaquete tema);

  /// Mostra/esconde e escala as peças conforme o plano.
  void aplicar(PlanoMaquete plano);

  /// O widget que desenha a cena com a câmera da reserva girada [giro]
  /// radianos, numa caixa com essa [proporcao] (largura / altura).
  /// [aoDesenhar] é chamado a cada quadro em que o relógio da cena anda,
  /// a partir do primeiro desenhado de fato (depois do aquecimento).
  /// [aoFalhar] é chamado uma vez se desenhar a cena lançar (no meio da
  /// pintura ou do aquecimento): a cena para de desenhar e quem chama volta
  /// para a imagem.
  Widget vista({
    required double proporcao,
    required double giro,
    required VoidCallback aoDesenhar,
    required void Function(Object erro) aoFalhar,
  });

  /// Tempo de CPU (ms) do último quadro da cena e chamadas de desenho dele.
  (double, int)? get ultimoQuadro;

  /// Libera a memória de GPU da cena.
  void descartar();
}

/// As peças do modelo que o plano mexe e os materiais de tema, de uma
/// instância carregada do `maquete.glb`. Só mexe em `Node`s e materiais do
/// flutter_scene, nada de GPU: dá para testar com uma árvore de nós montada
/// no teste.
class PecasMaquete {
  PecasMaquete._(this._nos, this._materiaisDeTema, this.fantasma);

  /// Procura no [modelo] todo nó que o plano usa e troca os materiais de
  /// tema e do fantasma por materiais desta instância. Lança [StateError]
  /// se faltar algum nó (glb fora de sincronia com o plano: o 3D mostraria
  /// peças erradas).
  ///
  /// Os materiais do modelo são compartilhados por toda cena carregada do
  /// mesmo glb (o `loadScene` guarda um molde por arquivo e cada instância
  /// reaproveita os materiais dele), então não são alterados. A troca tem de
  /// ser feita antes de o modelo entrar na cena: o `MeshComponent` registra
  /// os itens de desenho com o material da hora em que é montado.
  factory PecasMaquete.doModelo(fs.Node modelo, {required TemaMaquete tema}) {
    final nos = <String, fs.Node>{};
    final ausentes = <String>[];
    for (final nome in PlanoMaquete.todosOsNos) {
      final no = modelo.name == nome ? modelo : modelo.getChildByName(nome);
      if (no == null) {
        ausentes.add(nome);
      } else {
        nos[nome] = no;
      }
    }
    if (ausentes.isNotEmpty) {
      throw StateError('maquete.glb sem os nós ${ausentes.join(', ')}');
    }

    final fantasma = fs.UnlitMaterial()
      ..name = 'fantasma'
      ..doubleSided = true
      // Cor exata, sem o COLOR_0 da malha (se houver) multiplicando.
      ..vertexColorWeight = 0;
    final deTema = <String, fs.PhysicallyBasedMaterial>{};
    for (final no in modelo.meshNodes) {
      final mesh = no.mesh;
      if (mesh == null) continue;
      for (final primitiva in mesh.primitives) {
        final original = primitiva.material;
        if (original.name == 'fantasma') {
          fantasma
            ..depthBias = original.depthBias
            ..depthLayer = original.depthLayer;
          primitiva.material = fantasma;
          // O traço não projeta sombra (e, sem luz, não recebe).
          primitiva.castsShadow = false;
          no.shadowCastingMode = fs.ShadowCastingMode.off;
        } else if (tema.corDoMaterial(original.name) != null &&
            original is fs.PhysicallyBasedMaterial) {
          primitiva.material = deTema.putIfAbsent(
            original.name,
            () => fs.PhysicallyBasedMaterial()
              ..name = original.name
              ..metallicFactor = original.metallicFactor
              ..roughnessFactor = original.roughnessFactor
              ..occlusionStrength = original.occlusionStrength
              ..vertexColorWeight = original.vertexColorWeight
              ..alphaMode = original.alphaMode
              ..doubleSided = original.doubleSided
              ..depthBias = original.depthBias
              ..depthLayer = original.depthLayer,
          );
        }
      }
    }
    return PecasMaquete._(nos, deTema, fantasma)..aplicarTema(tema);
  }

  /// Nós que o plano mexe, pelo nome.
  final Map<String, fs.Node> _nos;

  /// Materiais de tema desta instância, pelo nome do material no glb.
  final Map<String, fs.PhysicallyBasedMaterial> _materiaisDeTema;

  /// Material único dos fantasmas desta instância.
  final fs.UnlitMaterial fantasma;

  /// Última escala escrita em cada nó (o getter `Node.scale` decompõe a
  /// matriz; guardar evita isso e evita escrever a mesma escala de novo).
  final Map<String, (double, double, double)> _escalas = {};

  /// O material de tema desta instância com esse nome (testes, painel).
  fs.PhysicallyBasedMaterial? materialDeTema(String nome) =>
      _materiaisDeTema[nome];

  /// Troca as cores de tema (claro/escuro). Os materiais mandam a cor para a
  /// GPU a cada quadro desenhado; basta pedir um novo desenho depois.
  void aplicarTema(TemaMaquete tema) {
    for (final entrada in _materiaisDeTema.entries) {
      final cor = tema.corDoMaterial(entrada.key);
      if (cor == null) continue;
      final l = TemaMaquete.linear(cor);
      entrada.value.baseColorFactor = vm.Vector4(l[0], l[1], l[2], 1);
    }
    final f = tema.fantasmaNaCena;
    fantasma.baseColorFactor = vm.Vector4(f[0], f[1], f[2], 1);
  }

  /// Mostra/esconde e escala os nós conforme o plano. Só escreve o que
  /// mudou (escrever a escala refaz a matriz do nó). Devolve se algo mudou.
  bool aplicar(PlanoMaquete plano) {
    var mudou = false;
    for (final entrada in plano.pecas.entries) {
      final no = _nos[entrada.key];
      if (no == null) continue;
      final estado = entrada.value;
      if (no.visible != estado.visivel) {
        no.visible = estado.visivel;
        mudou = true;
      }
      if (!estado.visivel) continue;
      final escala = (estado.escalaX, estado.escalaY, estado.escalaZ);
      if ((_escalas[entrada.key] ?? (1.0, 1.0, 1.0)) == escala) continue;
      // O getter devolve cópia: sempre atribuir um vetor novo.
      no.scale = vm.Vector3(estado.escalaX, estado.escalaY, estado.escalaZ);
      _escalas[entrada.key] = escala;
      mudou = true;
    }
    for (final entrada in plano.fantasmas.entries) {
      final no = _nos[entrada.key];
      if (no != null && no.visible != entrada.value) {
        no.visible = entrada.value;
        mudou = true;
      }
    }
    return mudou;
  }

  /// Visibilidade e escala atuais de um nó (para o painel e testes).
  (bool, double, double, double)? estadoDoNo(String nome) {
    final no = _nos[nome];
    if (no == null) return null;
    final e = _escalas[nome] ?? (1.0, 1.0, 1.0);
    return (no.visible, e.$1, e.$2, e.$3);
  }
}

/// A `Scene` do flutter_scene com o quadro protegido: uma exceção ao
/// desenhar (no `paint` do SceneView ou no aquecimento) não sobe para o
/// Flutter, que a relataria e deixaria o 3D em branco, repetindo o erro a
/// cada quadro. A primeira falha é entregue a [aoFalhar] e a cena para de
/// desenhar.
final class _CenaProtegida extends fs.Scene {
  void Function(Object erro)? aoFalhar;
  Object? _falha;

  @override
  void renderViews(
    List<fs.RenderView> views,
    ui.Canvas canvas, {
    ui.Rect? region,
    double? pixelRatio,
  }) {
    // Descartada: não há o que desenhar (desenhar lançaria StateError).
    if (_falha != null || isDisposed) return;
    try {
      super.renderViews(
        views,
        canvas,
        region: region,
        pixelRatio: pixelRatio,
      );
    } catch (erro, pilha) {
      _falha = erro;
      debugPrint('MaqueteObra: falha ao desenhar o 3D: $erro\n$pilha');
      aoFalhar?.call(erro);
    }
  }
}

/// A cena 3D da maquete em flutter_scene: carrega o `maquete.glb`
/// (convertido em `.fsceneb` no build pelo hook do flutter_scene), troca os
/// materiais de tema pelos desta instância ([PecasMaquete]), acende a luz e
/// aplica o [PlanoMaquete].
///
/// [carregar] lança se o Flutter GPU não está disponível (Impeller
/// desligado, Flutter GPU sem a chave no manifesto, aparelho sem suporte,
/// testes) ou se o modelo não tem algum nó que o plano usa: quem chama cai
/// na imagem de reserva.
class CenaMaquete implements Cena3dMaquete {
  CenaMaquete._(this._cena, this.pecas);

  /// Caminho de origem do modelo (o hook gera o `.fsceneb` a partir dele).
  static const String caminhoGlb = 'assets/3d/maquete.glb';

  /// Luz de janela das imagens de reserva (`gerar_maquete.py`: sol vindo de
  /// P(-10; 10; 8), cor 1/0,975/0,945), com o Z do glTF invertido para o
  /// flutter_scene. Direção em que a luz anda (da luz para a cena).
  static final vm.Vector3 direcaoDaLuz = vm.Vector3(10, -10, 8)..normalize();

  /// Intensidade do sol. O Cycles e o flutter_scene não usam a mesma escala;
  /// 3,0 é o padrão do flutter_scene e deixa a base quase branca, como na
  /// imagem. Ajustar no aparelho se o 3D sair mais claro ou escuro que a
  /// reserva.
  static const double intensidadeDaLuz = 3.0;

  final _CenaProtegida _cena;

  /// A cena do flutter_scene, para o `SceneView`.
  fs.Scene get cena => _cena;

  /// As peças e os materiais desta instância.
  final PecasMaquete pecas;

  /// Inicia o Flutter GPU, carrega o modelo e monta a cena. Lança se o
  /// Flutter GPU, o modelo ou a cena não iniciarem.
  static Future<CenaMaquete> carregar({required TemaMaquete tema}) async {
    // Shaders e recursos estáticos. Lança sem Impeller ou sem Flutter GPU
    // ("Flutter GPU requires the Impeller rendering backend..." nos testes).
    await fs.Scene.initializeStaticResources();
    final modelo = await fs.loadScene(caminhoGlb);
    final pecas = PecasMaquete.doModelo(modelo, tema: tema);

    final cena = _CenaProtegida();
    try {
      cena
        // A cor do fantasma é calculada para esta curva e esta exposição
        // (TemaMaquete.fantasmaNaCena); são os padrões, fixados aqui.
        ..exposure = 1.0
        ..toneMapping = fs.ToneMappingMode.pbrNeutral
        ..directionalLight = fs.DirectionalLight(
          direction: direcaoDaLuz,
          color: vm.Vector3(1.0, 0.975, 0.945),
          intensity: intensidadeDaLuz,
          castsShadow: true,
          // Sol grande (14° nas imagens): sombra macia.
          shadowSoftness: 0.12,
          // Cena pequena (tabuleiro de 14 x 12 m a ~28 m da câmera): duas
          // cascatas bastam.
          shadowCascadeCount: 2,
          shadowMaxDistance: 60,
        );
      // Só o último quadro interessa (painel de depuração).
      cena.renderStats.historyLength = 0;
      cena.add(modelo);
    } catch (_) {
      cena.dispose();
      rethrow;
    }
    return CenaMaquete._(cena, pecas);
  }

  @override
  void aplicarTema(TemaMaquete tema) => pecas.aplicarTema(tema);

  @override
  void aplicar(PlanoMaquete plano) {
    if (_cena.isDisposed) return;
    pecas.aplicar(plano);
  }

  /// Câmera da imagem de reserva, girada [giro] radianos em volta do eixo
  /// vertical, com o campo de visão casado com a imagem para uma caixa com
  /// essa [proporcao] (largura / altura).
  static fs.PerspectiveCamera camera({
    required double proporcao,
    double giro = 0,
  }) {
    final p = CameraMaquete.girar(CameraMaquete.posicao, giro);
    final a = CameraMaquete.girar(CameraMaquete.alvo, giro);
    return fs.PerspectiveCamera(
      fovRadiansY: CameraMaquete.fovVerticalPara(proporcao),
      position: vm.Vector3(p[0], p[1], p[2]),
      target: vm.Vector3(a[0], a[1], a[2]),
      up: vm.Vector3(0, 1, 0),
    );
  }

  /// O SceneView da cena. Com `warmUp`, ele compila os pipelines antes de
  /// mostrar o primeiro quadro (até lá não desenha nada; a MaqueteObra deixa
  /// a imagem por baixo) e só então começa a chamar o `onTick`. Sem
  /// `maxFrameRate`: na medição todo quadro do aparelho redesenha a cena, e
  /// assim todo tempo de quadro medido é de um quadro com o 3D.
  ///
  /// Cada SceneView novo redesenha a cena (o `didUpdateWidget` dele pede um
  /// quadro); a MaqueteObra só pede um novo quando algo mudou.
  @override
  Widget vista({
    required double proporcao,
    required double giro,
    required VoidCallback aoDesenhar,
    required void Function(Object erro) aoFalhar,
  }) {
    _cena.aoFalhar = aoFalhar;
    return fs.SceneView(
      _cena,
      camera: camera(proporcao: proporcao, giro: giro),
      warmUp: true,
      loadingBuilder: (context, progresso) => const SizedBox.expand(),
      onTick: (decorrido, delta) => aoDesenhar(),
    );
  }

  /// Tempo de CPU (ms) do último `Scene.render` e chamadas de desenho dele.
  @override
  (double, int)? get ultimoQuadro {
    final q = _cena.renderStats.latest;
    if (q == null) return null;
    return (q.cpuMicros / 1000, q.counters.draws);
  }

  /// Libera as texturas de desenho da cena (alvos de quadro, sombras). A
  /// geometria e os materiais do modelo ficam no cache do flutter_scene
  /// para a próxima abertura.
  @override
  void descartar() {
    _cena.aoFalhar = null;
    _cena.dispose();
  }
}
