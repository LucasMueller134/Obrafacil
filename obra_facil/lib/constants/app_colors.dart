import 'package:flutter/material.dart';

/// Paleta "Canteiro Premium" — tema escuro do ObraFácil.
///
/// Laranja de obra como cor de ação, cinza-cimento nas superfícies
/// e amarelo-capacete para alertas e destaques.
abstract class AppColors {
  // Marca
  static const Color laranja = Color(0xFFF97316);
  static const Color laranjaEscuro = Color(0xFFEA580C);
  static const Color amareloCapacete = Color(0xFFFBBF24);

  // Superfícies (escuro)
  static const Color fundo = Color(0xFF0F172A);
  static const Color superficie = Color(0xFF1E293B);
  static const Color superficieAlta = Color(0xFF273549);
  static const Color cinzaCimento = Color(0xFF374151);
  static const Color borda = Color(0xFF334155);

  // Texto
  static const Color textoPrimario = Color(0xFFF8FAFC);
  static const Color textoSecundario = Color(0xFF94A3B8);
  static const Color textoDesabilitado = Color(0xFF64748B);

  // Semânticas
  static const Color sucesso = Color(0xFF22C55E);
  static const Color erro = Color(0xFFEF4444);
  static const Color alerta = Color(0xFFFBBF24);
  static const Color info = Color(0xFF38BDF8);

  // Categorias de custo (gráficos)
  static const Color catMaoDeObra = Color(0xFF38BDF8);
  static const Color catMaterial = Color(0xFFF97316);
  static const Color catEquipamento = Color(0xFFA78BFA);
  static const Color catOutros = Color(0xFF94A3B8);
}
