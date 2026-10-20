import 'package:flutter/material.dart';

import '../movimento.dart';
import '../tipografia.dart';
import '../tokens.dart';
import 'area_pressionavel.dart';

/// Mostra um aviso no rodapé, com "Desfazer" opcional: é o que a prancheta
/// usa no lugar do diálogo de confirmação (aprovou, excluiu, arquivou →
/// aviso com desfazer).
///
/// Use isto em vez de montar o `SnackBar` à mão, porque:
/// - o aviso some sozinho em [Movimento.janelaDesfazer] (4 s). Um
///   `SnackBar` com ação, no Flutter atual, fica na tela até alguém tocar;
/// - com leitor de tela (navegação acessível), espera o toque, para dar
///   tempo de chegar no "Desfazer";
/// - o botão da ação é o da prancheta: laranja com texto preto, cantos de
///   2 dp e 48 dp de altura (o do Material é uma pílula com véu
///   translúcido, e o tema não alcança);
/// - um aviso novo substitui o anterior na hora, sem fila.
///
/// A vibração de confirmar ([Tato.confirmar]) fica com a tela, que sabe se
/// a ação deu certo.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> mostrarAviso(
  BuildContext context,
  String mensagem, {
  VoidCallback? aoDesfazer,
  String rotuloAcao = 'Desfazer',
}) {
  final mensageiro = ScaffoldMessenger.of(context);
  final acessivel = MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
  mensageiro.hideCurrentSnackBar();
  return mensageiro.showSnackBar(
    SnackBar(
      content: Text(mensagem),
      action: aoDesfazer == null
          ? null
          : _AcaoAviso(label: rotuloAcao, onPressed: aoDesfazer),
      duration: Movimento.janelaDesfazer,
      persist: aoDesfazer != null && acessivel,
    ),
  );
}

/// A ação do aviso com o botão da prancheta. Continua sendo uma
/// [SnackBarAction] para o `SnackBar` (que mede o rótulo dela e decide o
/// layout); só o desenho muda.
class _AcaoAviso extends SnackBarAction {
  const _AcaoAviso({required super.label, required super.onPressed});

  @override
  State<SnackBarAction> createState() => _AcaoAvisoState();
}

class _AcaoAvisoState extends State<SnackBarAction> {
  bool _tocou = false;

  void _tocar() {
    if (_tocou) return;
    setState(() => _tocou = true);
    widget.onPressed();
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar(reason: SnackBarClosedReason.action);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return AreaPressionavel(
      aoTocar: _tocou ? null : _tocar,
      rotuloSemantico: widget.label,
      vibrar: true,
      construtor: (context, e) => AnimatedContainer(
        duration: context.duracao(Movimento.rapido),
        curve: Movimento.entrar,
        constraints: const BoxConstraints(
          minHeight: Alvo.minimo,
          minWidth: Alvo.minimo,
        ),
        padding: const EdgeInsets.symmetric(horizontal: Espaco.e16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // Tocado, o aviso já está saindo: fica no laranja de sempre.
          color: e.pressionado ? c.marcaPressionada : c.marca,
          borderRadius: Raio.cantoPequeno,
        ),
        child: Text(
          widget.label,
          style: Tipografia.subtitulo.copyWith(color: c.sobreMarca),
          maxLines: 1,
        ),
      ),
    );
  }
}
