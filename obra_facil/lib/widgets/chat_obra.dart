import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/app_colors.dart';
import '../services/ia/perguntas_obra_service.dart';
import '../services/ia/voz_service.dart';

/// Conversa com o assistente da obra — usada pela equipe no relatório e
/// pelo cliente na área dele.
///
/// Em [modoCliente] a mesma IA responde só o que é de acompanhamento:
/// andamento, fases, materiais e previsão. Dinheiro fica fora, e não é só
/// a resposta que muda — quem monta os [dados] do cliente nem carrega os
/// lançamentos.
class ChatObra extends StatefulWidget {
  final DadosObraChat dados;
  final bool modoCliente;

  const ChatObra({
    super.key,
    required this.dados,
    this.modoCliente = false,
  });

  @override
  State<ChatObra> createState() => _ChatObraState();
}

class _ChatObraState extends State<ChatObra>
    with AutomaticKeepAliveClientMixin {
  final _campoCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _voz = VozService();
  bool _ouvindoVoz = false;
  late final List<MensagemChat> _mensagens = [
    MensagemChat(
      widget.modoCliente
          ? 'Olá! Sou o assistente da ${widget.dados.obra.nome}. Pergunte '
              'à vontade sobre o andamento: em que fase está, o que foi '
              'feito no canteiro, quais materiais estão sendo usados e '
              'quando deve ficar pronto. 👷'
          : 'Oi! Sou o assistente da ${widget.dados.obra.nome}. Pode '
              'perguntar do seu jeito — "como está a obra?", "quando acaba '
              'o cimento?", "quanto gastei essa semana?" — que eu respondo '
              'com os dados reais, sem internet. Erro de digitação não me '
              'assusta. 👷',
      deUsuario: false,
      sugestoes: widget.modoCliente
          ? PerguntasObraService.sugestoesCliente
          : PerguntasObraService.sugestoesIniciais,
    ),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _campoCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _enviar(String texto) {
    final pergunta = texto.trim();
    if (pergunta.isEmpty) return;
    final resposta = PerguntasObraService.responder(
      pergunta,
      widget.dados,
      modoCliente: widget.modoCliente,
    );
    setState(() {
      _mensagens.add(MensagemChat(pergunta, deUsuario: true));
      _mensagens.add(MensagemChat(resposta.texto,
          deUsuario: false, sugestoes: resposta.sugestoes));
      _campoCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _falar() async {
    if (_ouvindoVoz) {
      await _voz.parar();
      setState(() => _ouvindoVoz = false);
      return;
    }
    final ok = await _voz.inicializar();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Microfone indisponível — verifique a permissão.')));
      return;
    }
    setState(() => _ouvindoVoz = true);
    await _voz.ouvir((texto, finalizou) {
      if (!mounted) return;
      setState(() {
        _campoCtrl.text = texto;
        if (finalizou) _ouvindoVoz = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: _mensagens.length,
            itemBuilder: (_, i) {
              final msg = _mensagens[i];
              return _Bolha(
                msg: msg,
                mostrarSugestoes: i == _mensagens.length - 1,
                onSugestao: _enviar,
              )
                  .animate()
                  .fadeIn(duration: 220.ms)
                  .slideY(begin: 0.08, end: 0, duration: 260.ms);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: _ouvindoVoz ? 'Parar' : 'Perguntar por voz',
                  onPressed: _falar,
                  style: IconButton.styleFrom(
                    backgroundColor: _ouvindoVoz
                        ? AppColors.erro.withValues(alpha: 0.25)
                        : AppColors.superficieAlta,
                  ),
                  icon: Icon(
                    _ouvindoVoz ? Icons.stop : Icons.mic,
                    color: _ouvindoVoz ? AppColors.erro : AppColors.laranja,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _campoCtrl,
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: _enviar,
                    decoration: InputDecoration(
                      hintText:
                          _ouvindoVoz ? 'Ouvindo…' : 'Pergunte sobre a obra…',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Enviar',
                  onPressed: () => _enviar(_campoCtrl.text),
                  style:
                      IconButton.styleFrom(backgroundColor: AppColors.laranja),
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MensagemChat {
  final String texto;
  final bool deUsuario;
  final List<String> sugestoes;

  const MensagemChat(this.texto,
      {required this.deUsuario, this.sugestoes = const []});
}

class _Bolha extends StatelessWidget {
  final MensagemChat msg;
  final bool mostrarSugestoes;
  final void Function(String) onSugestao;

  const _Bolha({
    required this.msg,
    required this.mostrarSugestoes,
    required this.onSugestao,
  });

  @override
  Widget build(BuildContext context) {
    final bolha = Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: msg.deUsuario ? AppColors.laranja : AppColors.superficie,
        border: msg.deUsuario ? null : Border.all(color: AppColors.borda),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(msg.deUsuario ? 16 : 4),
          bottomRight: Radius.circular(msg.deUsuario ? 4 : 16),
        ),
      ),
      child: Text(
        msg.texto,
        style: TextStyle(
          color: msg.deUsuario ? Colors.white : AppColors.textoPrimario,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            msg.deUsuario ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                msg.deUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!msg.deUsuario) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.laranja,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.engineering,
                      size: 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(child: bolha),
            ],
          ),
          if (mostrarSugestoes && msg.sugestoes.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8, left: msg.deUsuario ? 0 : 36),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in msg.sugestoes)
                    ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      avatar: const Icon(Icons.bolt,
                          size: 14, color: AppColors.amareloCapacete),
                      onPressed: () => onSugestao(s),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
