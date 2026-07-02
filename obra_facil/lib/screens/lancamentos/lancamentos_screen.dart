// lib/screens/lancamentos/lancamentos_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/lancamento_model.dart';
import '../../providers/app_provider.dart';
import '../../constants/app_theme.dart';
import '../../constants/app_constants.dart';

class LancamentosScreen extends StatelessWidget {
  final String obraId;
  const LancamentosScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return StreamBuilder<List<LancamentoModel>>(
      stream: provider.firebaseService.streamLancamentos(obraId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final lancamentos = snapshot.data ?? [];
        if (lancamentos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.border),
                const SizedBox(height: 16),
                const Text('Nenhum lançamento ainda'),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: lancamentos.length,
          itemBuilder: (context, i) {
            final l = lancamentos[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconeCategoria(l.categoria),
                      color: AppTheme.primary, size: 20),
                ),
                title: Text(l.descricao,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  '${l.categoria} • ${l.fornecedorNome.isNotEmpty ? l.fornecedorNome : 'Sem fornecedor'}\n'
                  '${l.quantidade} ${l.unidade} × ${fmt.format(l.valorUnitario)}',
                ),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fmt.format(l.valorTotal),
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StatusPagChip(status: l.statusPagamento),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _iconeCategoria(String cat) {
    switch (cat) {
      case 'Mão de Obra': return Icons.engineering;
      case 'Materiais': return Icons.inventory_2_outlined;
      case 'Transporte': return Icons.local_shipping_outlined;
      default: return Icons.receipt_outlined;
    }
  }
}

class _StatusPagChip extends StatelessWidget {
  final String status;
  const _StatusPagChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color cor;
    switch (status) {
      case 'Pago': cor = AppTheme.success; break;
      case 'A Pagar': cor = AppTheme.error; break;
      default: cor = AppTheme.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(status,
          style: TextStyle(fontSize: 10, color: cor, fontWeight: FontWeight.w600)),
    );
  }
}
