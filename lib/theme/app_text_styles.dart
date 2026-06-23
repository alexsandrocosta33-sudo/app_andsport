import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Estilos de texto padronizados usando a fonte Poppins.
/// Parâmetro [cor] é opcional — se omitido, usa a cor padrão do estilo.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle titulo1({Color? cor}) => GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: cor ?? AppColors.textoPrimarioClaro,
        height: 1.2,
      );

  static TextStyle titulo2({Color? cor}) => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: cor ?? AppColors.textoPrimarioClaro,
        height: 1.3,
      );

  static TextStyle titulo3({Color? cor}) => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: cor ?? AppColors.textoPrimarioClaro,
      );

  static TextStyle corpo({Color? cor}) => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: cor ?? AppColors.textoPrimarioClaro,
        height: 1.5,
      );

  static TextStyle corpoPequeno({Color? cor}) => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: cor ?? AppColors.textoSecundarioClaro,
        height: 1.4,
      );

  static TextStyle botao({Color? cor}) => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: cor ?? Colors.white,
        letterSpacing: 0.5,
      );

  static TextStyle label({Color? cor}) => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: cor ?? AppColors.textoSecundarioClaro,
      );

  static TextStyle destaque({Color? cor}) => GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: cor ?? AppColors.acento,
      );
}
