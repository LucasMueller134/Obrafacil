import 'dart:math' as math;
import 'dart:ui';

/// Motor 3D mínimo, em Dart puro, para as cenas do app.
///
/// Por que escrever um em vez de usar biblioteca: as cenas do ObraFácil são
/// low-poly (algumas centenas de faces), precisam rodar offline em celular
/// fraco, e o que se quer é exatamente o controle fino — cor de tijolo,
/// sombra chapada, aresta desenhada. Um rasterizador por ordenação de
/// profundidade (algoritmo do pintor) dá isso em ~200 linhas testáveis.
///
/// Convenção: eixo Y para cima, X para a direita, Z apontando para quem
/// olha. A câmera fica no eixo Z, olhando para a origem.
class Vetor3 {
  final double x, y, z;

  const Vetor3(this.x, this.y, this.z);

  static const zero = Vetor3(0, 0, 0);

  Vetor3 operator +(Vetor3 o) => Vetor3(x + o.x, y + o.y, z + o.z);
  Vetor3 operator -(Vetor3 o) => Vetor3(x - o.x, y - o.y, z - o.z);
  Vetor3 operator *(double k) => Vetor3(x * k, y * k, z * k);

  double dot(Vetor3 o) => x * o.x + y * o.y + z * o.z;

  Vetor3 cross(Vetor3 o) => Vetor3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double get comprimento => math.sqrt(x * x + y * y + z * z);

  Vetor3 get normalizado {
    final c = comprimento;
    return c == 0 ? this : Vetor3(x / c, y / c, z / c);
  }

  /// Gira em torno do eixo Y (a rotação "de vitrine").
  Vetor3 girarY(double angulo) {
    final c = math.cos(angulo), s = math.sin(angulo);
    return Vetor3(x * c + z * s, y, -x * s + z * c);
  }

  /// Gira em torno do eixo X (inclinar a câmera para olhar de cima).
  Vetor3 girarX(double angulo) {
    final c = math.cos(angulo), s = math.sin(angulo);
    return Vetor3(x, y * c - z * s, y * s + z * c);
  }

  @override
  String toString() => 'Vetor3($x, $y, $z)';
}

/// Acabamento da superfície — o que o pintor desenha por cima da cor.
enum Textura {
  lisa,

  /// Fiadas de tijolo com junta de argamassa.
  tijolo,

  /// Poros e manchas de concreto.
  concreto,

  /// Veios de madeira.
  madeira,

  /// Ondas de telha cerâmica.
  telha,
}

/// Uma face plana: índices dos vértices (sentido anti-horário visto de
/// fora), cor base e acabamento.
class Face {
  final List<int> indices;
  final Color cor;
  final Textura textura;

  const Face(this.indices, this.cor, {this.textura = Textura.lisa});
}

/// Conjunto de vértices e faces. Imutável: transformar devolve outra.
class Malha {
  final List<Vetor3> vertices;
  final List<Face> faces;

  const Malha(this.vertices, this.faces);

  Malha transladar(Vetor3 d) =>
      Malha([for (final v in vertices) v + d], faces);

  Malha girarY(double angulo) =>
      Malha([for (final v in vertices) v.girarY(angulo)], faces);

  /// Caixa alinhada aos eixos, centrada em [centro].
  ///
  /// [cores] permite pintar topo, laterais e fundo diferente — é o que dá
  /// a leitura de volume mesmo sem luz: o topo sempre mais claro.
  factory Malha.caixa({
    required Vetor3 centro,
    required Vetor3 tamanho,
    required Color cor,
    Color? corTopo,
    Textura textura = Textura.lisa,
    Textura? texturaTopo,
  }) {
    final dx = tamanho.x / 2, dy = tamanho.y / 2, dz = tamanho.z / 2;
    final c = centro;
    final v = [
      Vetor3(c.x - dx, c.y - dy, c.z + dz), // 0 frente-baixo-esq
      Vetor3(c.x + dx, c.y - dy, c.z + dz), // 1 frente-baixo-dir
      Vetor3(c.x + dx, c.y + dy, c.z + dz), // 2 frente-cima-dir
      Vetor3(c.x - dx, c.y + dy, c.z + dz), // 3 frente-cima-esq
      Vetor3(c.x - dx, c.y - dy, c.z - dz), // 4 trás-baixo-esq
      Vetor3(c.x + dx, c.y - dy, c.z - dz), // 5 trás-baixo-dir
      Vetor3(c.x + dx, c.y + dy, c.z - dz), // 6 trás-cima-dir
      Vetor3(c.x - dx, c.y + dy, c.z - dz), // 7 trás-cima-esq
    ];
    final topo = corTopo ?? cor;
    return Malha(v, [
      Face(const [0, 1, 2, 3], cor, textura: textura), // frente
      Face(const [5, 4, 7, 6], cor, textura: textura), // trás
      Face(const [4, 0, 3, 7], cor, textura: textura), // esquerda
      Face(const [1, 5, 6, 2], cor, textura: textura), // direita
      Face(const [3, 2, 6, 7], topo,
          textura: texturaTopo ?? textura), // topo
      Face(const [4, 5, 1, 0], cor), // fundo
    ]);
  }

  /// Telhado de duas águas: prisma triangular deitado ao longo de X.
  factory Malha.telhado({
    required Vetor3 centroBase,
    required double largura,
    required double profundidade,
    required double altura,
    required Color cor,
    Color? corEmpena,
    Textura textura = Textura.lisa,
  }) {
    final dx = largura / 2, dz = profundidade / 2;
    final c = centroBase;
    final v = [
      Vetor3(c.x - dx, c.y, c.z + dz), // 0 frente-esq
      Vetor3(c.x + dx, c.y, c.z + dz), // 1 frente-dir
      Vetor3(c.x + dx, c.y, c.z - dz), // 2 trás-dir
      Vetor3(c.x - dx, c.y, c.z - dz), // 3 trás-esq
      Vetor3(c.x - dx, c.y + altura, c.z), // 4 cumeeira-esq
      Vetor3(c.x + dx, c.y + altura, c.z), // 5 cumeeira-dir
    ];
    final empena = corEmpena ?? cor;
    return Malha(v, [
      Face(const [0, 1, 5, 4], cor, textura: textura), // água da frente
      Face(const [2, 3, 4, 5], cor, textura: textura), // água de trás
      Face(const [3, 0, 4], empena), // empena esquerda
      Face(const [1, 2, 5], empena), // empena direita
      Face(const [3, 2, 1, 0], cor), // fundo (nunca visível)
    ]);
  }

  /// Cilindro vertical de poucos lados — tambor de betoneira, poste.
  factory Malha.cilindro({
    required Vetor3 centroBase,
    required double raio,
    required double altura,
    required Color cor,
    int lados = 8,
    Color? corTopo,
  }) {
    final v = <Vetor3>[];
    for (var i = 0; i < lados; i++) {
      final a = 2 * math.pi * i / lados;
      final x = centroBase.x + raio * math.cos(a);
      final z = centroBase.z + raio * math.sin(a);
      v.add(Vetor3(x, centroBase.y, z));
      v.add(Vetor3(x, centroBase.y + altura, z));
    }
    final faces = <Face>[];
    for (var i = 0; i < lados; i++) {
      final j = (i + 1) % lados;
      faces.add(Face([i * 2, i * 2 + 1, j * 2 + 1, j * 2], cor));
    }
    faces.add(Face(
      [for (var i = lados - 1; i >= 0; i--) i * 2 + 1],
      corTopo ?? cor,
    ));
    return Malha(v, faces);
  }
}

/// Face já projetada, pronta para pintar.
///
/// Em vez de uma cor só, carrega o par claro/escuro e onde cada um cai na
/// tela: preenchida com gradiente, a superfície ganha a variação contínua
/// de luz que uma face chapada não tem — é o que separa maquete de
/// desenho vetorial.
class FaceProjetada {
  final List<Offset> pontos;

  /// Cor no ponto mais iluminado da face e no mais sombreado.
  final Color corClara;
  final Color corEscura;

  /// Extremos do gradiente, em coordenadas de tela.
  final Offset inicioLuz;
  final Offset fimLuz;

  final Textura textura;
  final double profundidade;

  const FaceProjetada({
    required this.pontos,
    required this.corClara,
    required this.corEscura,
    required this.inicioLuz,
    required this.fimLuz,
    required this.textura,
    required this.profundidade,
  });
}

/// Contorno da cena achatado no chão — a sombra projetada.
class SombraProjetada {
  final List<List<Offset>> silhuetas;

  const SombraProjetada(this.silhuetas);
}

/// Câmera + luz. Projeta uma lista de malhas em faces 2D já ordenadas,
/// iluminadas e sem as costas.
class Camera3D {
  /// Rotação de vitrine (em torno de Y), em radianos.
  final double giro;

  /// Inclinação para olhar de cima, em radianos.
  final double inclinacao;

  /// Distância da câmera à origem.
  final double distancia;

  /// Fator de perspectiva — maior = lente mais longa, menos distorção.
  final double foco;

  /// Direção da luz, no espaço do mundo (antes do giro).
  final Vetor3 luz;

  const Camera3D({
    this.giro = 0,
    this.inclinacao = 0.42,
    this.distancia = 9,
    this.foco = 7,
    this.luz = const Vetor3(-0.5, 1, 0.7),
  });

  /// Transforma um ponto do mundo para o espaço da câmera.
  Vetor3 paraCamera(Vetor3 p) => p.girarY(giro).girarX(inclinacao);

  /// Ponto do espaço da câmera → tela (origem no centro, Y para cima).
  Offset projetar(Vetor3 p) {
    final d = distancia - p.z;
    final k = foco / (d <= 0.01 ? 0.01 : d);
    return Offset(p.x * k, -p.y * k);
  }

  /// Altura do chão da cena — referência da oclusão e da sombra.
  static const double chao = -1.2;

  /// Altura de referência para o topo da cena.
  static const double _tetoCena = 2.4;

  /// Faces visíveis, iluminadas e ordenadas do fundo para a frente.
  List<FaceProjetada> renderizar(Iterable<Malha> malhas) {
    final saida = <FaceProjetada>[];
    final luzCam = luz.girarY(giro).girarX(inclinacao).normalizado;
    final olho = Vetor3(0, 0, distancia);

    for (final malha in malhas) {
      final vc = [for (final v in malha.vertices) paraCamera(v)];
      for (final face in malha.faces) {
        if (face.indices.length < 3) continue;
        final a = vc[face.indices[0]];
        final b = vc[face.indices[1]];
        final c = vc[face.indices[2]];
        final normal = (b - a).cross(c - a).normalizado;
        // Costas: normal apontando para longe do olho.
        if (normal.dot(olho - a) <= 0) continue;

        final difusa = math.max(0.0, normal.dot(luzCam));
        // Brilho especular estreito: o realce que faz a superfície
        // parecer ter material, e não papel colorido.
        final reflexo = (normal * (2 * normal.dot(luzCam))) - luzCam;
        final especular =
            math.pow(math.max(0.0, reflexo.normalizado.z), 18).toDouble();
        final baseLuz = 0.46 + 0.54 * difusa + 0.22 * especular;

        // Oclusão por altura: o que está perto do chão recebe menos luz
        // do céu. É o que assenta a construção no terreno em vez de
        // deixá-la boiando.
        var profundidade = 0.0;
        final pontos = <Offset>[];
        var menorFator = double.infinity, maiorFator = -double.infinity;
        var pontoEscuro = Offset.zero, pontoClaro = Offset.zero;

        for (final i in face.indices) {
          final vMundo = malha.vertices[i];
          final tela = projetar(vc[i]);
          profundidade += vc[i].z;
          pontos.add(tela);

          final altura =
              ((vMundo.y - chao) / (_tetoCena - chao)).clamp(0.0, 1.0);
          final fator = baseLuz * (0.62 + 0.38 * altura);
          if (fator < menorFator) {
            menorFator = fator;
            pontoEscuro = tela;
          }
          if (fator > maiorFator) {
            maiorFator = fator;
            pontoClaro = tela;
          }
        }

        saida.add(FaceProjetada(
          pontos: pontos,
          corClara: _iluminar(face.cor, maiorFator),
          corEscura: _iluminar(face.cor, menorFator),
          inicioLuz: pontoEscuro,
          fimLuz: pontoClaro,
          textura: face.textura,
          profundidade: profundidade / face.indices.length,
        ));
      }
    }
    // Do mais fundo (z menor) para o mais perto.
    saida.sort((a, b) => a.profundidade.compareTo(b.profundidade));
    return saida;
  }

  /// Silhueta da cena achatada no plano do chão, na direção da luz.
  ///
  /// Sombra de verdade — o contorno acompanha o que existe e gira junto
  /// com a cena. Um borrão oval fixo denuncia na hora que é decoração.
  SombraProjetada projetarSombra(Iterable<Malha> malhas) {
    final luzMundo = luz.normalizado;
    final silhuetas = <List<Offset>>[];

    for (final malha in malhas) {
      for (final face in malha.faces) {
        // Só o que está acima do chão lança sombra.
        final acima = face.indices
            .every((i) => malha.vertices[i].y > chao + 0.02);
        if (!acima) continue;

        final pontos = <Offset>[];
        for (final i in face.indices) {
          final v = malha.vertices[i];
          // Desce o vértice até o chão seguindo o raio de luz.
          final t = (v.y - chao) / (luzMundo.y.abs() < 0.05 ? 0.05 : luzMundo.y);
          final noChao = Vetor3(v.x - luzMundo.x * t, chao, v.z - luzMundo.z * t);
          pontos.add(projetar(paraCamera(noChao)));
        }
        silhuetas.add(pontos);
      }
    }
    return SombraProjetada(silhuetas);
  }

  static Color _iluminar(Color cor, double fator) {
    final f = fator.clamp(0.0, 1.25);
    int canal(double c) => (c * 255 * f).round().clamp(0, 255);
    return Color.fromARGB(
        (cor.a * 255).round(), canal(cor.r), canal(cor.g), canal(cor.b));
  }
}
