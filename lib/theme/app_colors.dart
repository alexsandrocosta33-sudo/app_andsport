import 'package:flutter/material.dart';

/// Paleta de cores centralizada do AndSport.
/// Todos os widgets devem referenciar estas constantes em vez de hardcodar valores.
class AppColors {
  AppColors._();

  // --- Cores primárias (dark navy — seriedade e profissionalismo) ---
  static const Color primaria = Color(0xFF1A1A2E);
  static const Color primariaMedia = Color(0xFF16213E);
  static const Color primariaClara = Color(0xFF0F3460);

  // --- Acento (laranja energético — motivação e ação) ---
  static const Color acento = Color(0xFFFF6B35);
  static const Color acentoEscuro = Color(0xFFE55A28);
  static const Color acentoClaro = Color(0xFFFF8C5A);

  // --- Backgrounds ---
  static const Color fundoClaro = Color(0xFFF5F5F5);
  static const Color fundoEscuro = Color(0xFF121212);
  static const Color superficieClara = Colors.white;
  static const Color superficieEscura = Color(0xFF1E1E1E);
  static const Color cardClaro = Colors.white;
  static const Color cardEscuro = Color(0xFF2A2A2A);

  // --- Texto ---
  static const Color textoPrimarioClaro = Color(0xFF1A1A1A);
  static const Color textoSecundarioClaro = Color(0xFF757575);
  static const Color textoPrimarioEscuro = Color(0xFFF5F5F5);
  static const Color textoSecundarioEscuro = Color(0xFFB0B0B0);

  // --- Status ---
  static const Color sucesso = Color(0xFF4CAF50);
  static const Color erro = Color(0xFFE53935);
  static const Color aviso = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // --- Divisores ---
  static const Color divisorClaro = Color(0xFFE0E0E0);
  static const Color divisorEscuro = Color(0xFF333333);
}
