import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../design/design.dart';
import '../services/ia/assistente_ia_servidor.dart';
import '../services/ia/perguntas_obra_service.dart';
import '../services/ia/resumo_obra_ia.dart';
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

  /// `dono`, `mestre` ou `cliente`: vai para a IA do servidor, que responde
  /// conforme o perfil. Sem ele: cliente no [modoCliente], senão dono.
  final String? perfil;

  /// A IA do servidor, para o que as regras não entendem. Sem endereço no
  /// build (IA_URL), fica desligada e o chat é só regras, offline.
  final AssistenteIaServidor? ia;

  const ChatObra({
    super.key,
    required this.dados,
    this.modoCliente = false,
    this.perfil,
    this.ia,
  });

  @override
  State<ChatObra> createState() => _ChatObraState();
}

class _ChatObraState extends State<ChatObra>
    with AutomaticKeepAliveClientMixin {
  final _campoCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _voz = VozService();
  late final AssistenteIaServidor _ia = widget.ia ?? AssistenteIaServidor();
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
    // Saiu da tela falando: o microfone não fica aberto.
    if (_ouvindoVoz) unawaited(_voz.cancelar());
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
    final perguntarIa = resposta.intencao == 'nao_sei' && _ia.ligado;
    final historico = [
      for (final m in _mensagens.skip(1).toList().reversed.take(6).toList().reversed)
        {'role': m.deUsuario ? 'user' : 'assistant', 'content': m.texto},
    ];
    setState(() {
      _mensagens.add(MensagemChat(pergunta, deUsuario: true));
      _mensagens.add(perguntarIa
          ? const MensagemChat('Não achei isso nas respostas rápidas. Perguntando à IA…',
              deUsuario: false)
          : MensagemChat(resposta.texto,
              deUsuario: false, sugestoes: resposta.sugestoes));
      _campoCtrl.clear();
    });
    if (perguntarIa) unawaited(_perguntarIa(pergunta, resposta, historico));
    _rolarParaOFim();
  }

  /// As regras não entenderam: a IA do servidor responde com o resumo da
  /// obra. Se ela falhar (sem internet, servidor fora), fica a resposta das
  /// regras.
  Future<void> _perguntarIa(
      String pergunta, RespostaObra dasRegras, List<Map<String, String>> historico) async {
    final indice = _mensagens.length - 1;
    final ia = await _ia.perguntar(
      pergunta: pergunta,
      perfil: widget.perfil ?? (widget.modoCliente ? 'cliente' : 'dono'),
      obra: resumoObraParaIa(widget.dados, modoCliente: widget.modoCliente),
      historico: historico,
    );
    if (!mounted || indice >= _mensagens.length) return;
    setState(() {
      _mensagens[indice] = ia != null
          ? MensagemChat(ia.texto, deUsuario: false)
          : MensagemChat(dasRegras.texto, deUsuario: false, sugestoes: dasRegras.sugestoes);
    });
    _rolarParaOFim();
  }

  void _rolarParaOFim() {
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

  /// Pergunta por voz, no aparelho. [online] só quando o usuário escolheu
  /// o reconhecimento do Google depois de ver que falta o pacote offline.
  Future<void> _falar({bool online = false}) async {
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
    await _voz.ouvir(
      (texto, finalizou) {
        if (!mounted) return;
        setState(() {
          _campoCtrl.text = texto;
          if (finalizou) _ouvindoVoz = false;
        });
      },
      online: online,
      // Sem estes dois, um erro do reconhecedor deixava o botão em
      // "ouvindo" para sempre.
      onErro: (erro) {
        if (!mounted) return;
        unawaited(Tato.erro());
        mostrarAviso(
          context,
          erro.mensagem,
          rotuloAcao: 'Usar online do Google',
          aoDesfazer: erro.ofereceOnline ? () => _falar(online: true) : null,
        );
      },
      onFim: () {
        if (mounted) setState(() => _ouvindoVoz = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.cores;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(
                Espaco.margem, Espaco.e16, Espaco.margem, Espaco.e8),
            itemCount: _mensagens.length,
            itemBuilder: (_, i) {
              final msg = _mensagens[i];
              return _Bolha(
                msg: msg,
                mostrarSugestoes: i == _mensagens.length - 1,
                onSugestao: _enviar,
              )
                  .animate()
                  .fadeIn(duration: context.duracao(Movimento.medio))
                  .slideY(
                      begin: 0.08,
                      end: 0,
                      duration: context.duracao(Movimento.medio));
            },
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.papel,
            border: Border(top: BorderSide(color: c.grade, width: Traco.fino)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  Espaco.e12, Espaco.e8, Espaco.e12, Espaco.e8),
              child: Row(
                children: [
                  BotaoIcone(
                    icone: _ouvindoVoz ? Icons.stop : Icons.mic_none,
                    rotulo: _ouvindoVoz ? 'Parar' : 'Perguntar por voz',
                    tamanho: Alvo.opcao,
                    estilo: _ouvindoVoz
                        ? EstiloBotaoIcone.marca
                        : EstiloBotaoIcone.contorno,
                    aoTocar: _falar,
                  ),
                  const SizedBox(width: Espaco.e8),
                  Expanded(
                    child: TextField(
                      controller: _campoCtrl,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: _enviar,
                      decoration: InputDecoration(
                        hintText:
                            _ouvindoVoz ? 'Ouvindo…' : 'Pergunte sobre a obra…',
                      ),
                    ),
                  ),
                  const SizedBox(width: Espaco.e8),
                  BotaoIcone(
                    icone: Icons.send,
                    rotulo: 'Enviar',
                    tamanho: Alvo.opcao,
                    estilo: EstiloBotaoIcone.principal,
                    aoTocar: () => _enviar(_campoCtrl.text),
                  ),
                ],
              ),
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
    final c = context.cores;
    final bolha = Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
      padding: const EdgeInsets.symmetric(
          horizontal: Espaco.e12, vertical: Espaco.e8 + 2),
      decoration: BoxDecoration(
        color: msg.deUsuario ? c.grafite : c.folha,
        border: msg.deUsuario
            ? null
            : Border.all(color: c.traco, width: Traco.fino),
        borderRadius: Raio.cantoPequeno,
      ),
      child: Text(
        msg.texto,
        style: Tipografia.corpo.copyWith(
          color: msg.deUsuario ? c.sobreGrafite : c.grafite,
          height: 1.4,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: Espaco.e12),
      child: Column(
        crossAxisAlignment:
            msg.deUsuario ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                msg.deUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!msg.deUsuario) ...[
                ExcludeSemantics(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration:
                        BoxDecoration(color: c.marca, shape: BoxShape.circle),
                    child: Icon(Icons.engineering_outlined,
                        size: 20, color: c.sobreMarca),
                  ),
                ),
                const SizedBox(width: Espaco.e8),
              ],
              Flexible(child: bolha),
            ],
          ),
          if (mostrarSugestoes && msg.sugestoes.isNotEmpty)
            Padding(
              padding:
                  EdgeInsets.only(top: Espaco.e8, left: msg.deUsuario ? 0 : 40),
              child: Wrap(
                spacing: Espaco.e8,
                runSpacing: Espaco.e8,
                children: [
                  for (final s in msg.sugestoes)
                    ActionChip(
                      label: Text(s,
                          style: Tipografia.apoio.copyWith(color: c.grafite)),
                      avatar: Icon(Icons.bolt, size: 18, color: c.marcaTexto),
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
