import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/models.dart';
import '../../router/transicoes.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/perguntas_obra_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/animacoes.dart';
import '../../widgets/carregando_obra.dart';
import '../../widgets/chat_obra.dart';
import '../../widgets/imagem_obra.dart';

/// Acompanhamento da obra para quem a contratou.
///
/// Mostra andamento, fases, o que a equipe registrou no canteiro e as
/// fotos — e só isso. Os lançamentos nem são consultados: as regras do
/// Firestore recusam a leitura para o perfil cliente, então não existe
/// caminho, nem por engano de tela, que traga valor para cá.
class ClienteObraScreen extends StatelessWidget {
  final String obraId;

  const ClienteObraScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();

    return StreamBuilder<ObraModel?>(
      stream: db.obra(obraId),
      builder: (context, obraSnap) {
        final obra = obraSnap.data;
        if (obra == null) {
          return const Scaffold(
            body: TrocaSuave(child: CarregandoObra(mensagem: 'Abrindo a obra…')),
          );
        }
        return StreamBuilder<List<CronogramaFaseModel>>(
          stream: db.cronograma(obraId),
          builder: (context, cronoSnap) {
            final cronograma =
                cronoSnap.data ?? const <CronogramaFaseModel>[];
            return StreamBuilder<List<DiarioEntradaModel>>(
              stream: db.diario(obraId),
              builder: (context, diarioSnap) {
                final diario =
                    diarioSnap.data ?? const <DiarioEntradaModel>[];
                return _Acompanhamento(
                  obra: obra,
                  cronograma: cronograma,
                  diario: diario,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _Acompanhamento extends StatelessWidget {
  final ObraModel obra;
  final List<CronogramaFaseModel> cronograma;
  final List<DiarioEntradaModel> diario;

  const _Acompanhamento({
    required this.obra,
    required this.cronograma,
    required this.diario,
  });

  int get _percentualFisico {
    if (cronograma.isEmpty) return 0;
    final soma =
        cronograma.fold<int>(0, (s, f) => s + f.percentualConcluido);
    return (soma / cronograma.length).round();
  }

  List<CronogramaFaseModel> get _fasesAtuais =>
      cronograma.where((f) => f.emAndamento).toList();

  @override
  Widget build(BuildContext context) {
    final recentes = [...diario]..sort((a, b) => b.data.compareTo(a.data));
    final fases = [...cronograma]..sort((a, b) => a.ordem.compareTo(b.ordem));

    return Scaffold(
      appBar: AppBar(title: Text(obra.nome)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).padding.bottom + 96),
        children: [
          _CartaoAndamento(
            obra: obra,
            percentualFisico: _percentualFisico,
            fasesAtuais: _fasesAtuais,
          ).aparecerSecao(0),
          const SizedBox(height: 16),
          if (fases.isNotEmpty) ...[
            _Secao(
              titulo: 'Etapas da obra',
              child: Column(
                children: [
                  for (final fase in fases) _LinhaFase(fase: fase),
                ],
              ),
            ).aparecerSecao(1),
            const SizedBox(height: 16),
          ],
          _Secao(
            titulo: 'O que aconteceu no canteiro',
            child: recentes.isEmpty
                ? Text(
                    'A equipe ainda não registrou nenhum dia de trabalho.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textoSecundario),
                  )
                : Column(
                    children: [
                      for (final entrada in recentes.take(5))
                        _RegistroDoDia(entrada: entrada),
                    ],
                  ),
          ).aparecerSecao(2),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirChat(context),
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Perguntar sobre a obra'),
      ),
    );
  }

  void _abrirChat(BuildContext context) {
    // Os dados do chat do cliente vão sem lançamento, estoque nem
    // movimento: não há o que somar, mesmo que a pergunta insista.
    final dados = DadosObraChat(
      obra: obra,
      lancamentos: const [],
      diario: diario,
      cronograma: cronograma,
      estoque: const [],
      movimentos: const [],
    );
    Navigator.of(context).push(rotaSuave(
      Scaffold(
        appBar: AppBar(title: Text('Assistente · ${obra.nome}')),
        body: ChatObra(dados: dados, modoCliente: true),
      ),
    ));
  }
}

class _CartaoAndamento extends StatelessWidget {
  final ObraModel obra;
  final int percentualFisico;
  final List<CronogramaFaseModel> fasesAtuais;

  const _CartaoAndamento({
    required this.obra,
    required this.percentualFisico,
    required this.fasesAtuais,
  });

  @override
  Widget build(BuildContext context) {
    final pctPrazo = obra.duracaoDias <= 0
        ? 0
        : (obra.diasDecorridos / obra.duracaoDias * 100).round().clamp(0, 100);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            obra.endereco,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textoSecundario),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percentualFisico%',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.laranja,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'concluído',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textoSecundario),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentualFisico / 100,
              minHeight: 10,
              backgroundColor: AppColors.superficieAlta,
            ),
          ),
          const SizedBox(height: 16),
          if (fasesAtuais.isNotEmpty) ...[
            _Info(
              icone: Icons.construction,
              rotulo: 'Fase atual',
              valor: fasesAtuais.map((f) => f.nome).join(' e '),
            ),
            const SizedBox(height: 8),
          ],
          _Info(
            icone: Icons.event_available,
            rotulo: 'Entrega prevista',
            valor: Formatters.data(obra.previsaoTermino),
          ),
          const SizedBox(height: 8),
          _Info(
            icone: Icons.timelapse,
            rotulo: 'Prazo decorrido',
            valor: '${obra.diasDecorridos} de ${obra.duracaoDias} dias '
                '($pctPrazo%)',
          ),
          const SizedBox(height: 8),
          _Info(
            icone: Icons.flag_outlined,
            rotulo: 'Situação',
            valor: obra.status.label,
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String valor;

  const _Info({
    required this.icone,
    required this.rotulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 16, color: AppColors.laranja),
        const SizedBox(width: 8),
        SizedBox(
          width: 116,
          child: Text(
            rotulo,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textoSecundario),
          ),
        ),
        Expanded(
          child: Text(
            valor,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _LinhaFase extends StatelessWidget {
  final CronogramaFaseModel fase;

  const _LinhaFase({required this.fase});

  Color get _cor {
    if (fase.concluida) return AppColors.sucesso;
    if (fase.atrasada) return AppColors.erro;
    if (fase.emAndamento) return AppColors.laranja;
    return AppColors.textoDesabilitado;
  }

  String get _situacao {
    if (fase.concluida) return 'Concluída';
    if (fase.atrasada) return 'Em atraso';
    if (fase.emAndamento) return 'Em andamento';
    return 'A começar';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: _cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fase.nome,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  '$_situacao · ${Formatters.data(fase.dataInicio)} a '
                  '${Formatters.data(fase.dataFim)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textoSecundario),
                ),
              ],
            ),
          ),
          Text(
            '${fase.percentualConcluido}%',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: _cor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RegistroDoDia extends StatelessWidget {
  final DiarioEntradaModel entrada;

  const _RegistroDoDia({required this.entrada});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                Formatters.diaSemana(entrada.data),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                entrada.clima,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textoSecundario),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(entrada.descricao,
              style: Theme.of(context).textTheme.bodyMedium),
          if (entrada.fotosUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: entrada.fotosUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 150,
                    child: ImagemObra(entrada.fotosUrls[i]),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  final Widget child;

  const _Secao({required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
