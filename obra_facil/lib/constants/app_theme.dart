import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tema escuro "Canteiro Premium".
abstract class AppTheme {
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.fundo,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.laranja,
        onPrimary: Colors.white,
        secondary: AppColors.amareloCapacete,
        onSecondary: Color(0xFF1F2937),
        surface: AppColors.superficie,
        onSurface: AppColors.textoPrimario,
        error: AppColors.erro,
        onError: Colors.white,
        outline: AppColors.borda,
      ),
    );

    // Título com entrelinha apertada e texto corrido com respiro: é o
    // ajuste que separa "fonte bonita aplicada" de tipografia cuidada.
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme)
        .apply(
          bodyColor: AppColors.textoPrimario,
          displayColor: AppColors.textoPrimario,
        )
        .copyWith(
          displaySmall: GoogleFonts.poppins(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: AppColors.textoPrimario),
          headlineMedium: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: AppColors.textoPrimario),
          titleLarge: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: AppColors.textoPrimario),
          titleMedium: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: AppColors.textoPrimario),
          bodyMedium: GoogleFonts.poppins(
              fontSize: 14, height: 1.5, color: AppColors.textoPrimario),
          bodySmall: GoogleFonts.poppins(
              fontSize: 12.5, height: 1.45, color: AppColors.textoPrimario),
        );

    return base.copyWith(
      textTheme: textTheme,
      // Respingo mais suave que o padrão, sem o círculo duro do Material 2.
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.fundo,
        foregroundColor: AppColors.textoPrimario,
        elevation: 0,
        // Sem isso a barra muda de cor ao rolar a lista — o detalhe que
        // mais entrega app montado às pressas.
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textoPrimario,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borda),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.laranja,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.cinzaCimento,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.laranja,
          side: const BorderSide(color: AppColors.laranja, width: 1.5),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.laranja,
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.superficie,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borda),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borda),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.laranja, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.erro),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.erro, width: 2),
        ),
        labelStyle:
            GoogleFonts.poppins(color: AppColors.textoSecundario, fontSize: 14),
        hintStyle:
            GoogleFonts.poppins(color: AppColors.textoDesabilitado, fontSize: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.superficie,
        indicatorColor: AppColors.laranja.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.laranja
                : AppColors.textoSecundario,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.laranja,
        foregroundColor: Colors.white,
        elevation: 6,
        // A sombra puxa o laranja em vez do preto: o botão parece aceso
        // sobre o fundo escuro, e não colado com um borrão cinza.
        splashColor: Colors.white.withValues(alpha: 0.18),
        extendedTextStyle: GoogleFonts.poppins(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.superficieAlta,
        selectedColor: AppColors.laranja.withValues(alpha: 0.2),
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          color: AppColors.textoPrimario,
        ),
        side: const BorderSide(color: AppColors.borda),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borda,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.superficieAlta,
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.textoPrimario,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.superficie,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.superficie,
        showDragHandle: true,
        dragHandleColor: AppColors.cinzaCimento,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.laranja,
        linearTrackColor: AppColors.cinzaCimento,
        circularTrackColor: AppColors.cinzaCimento,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.laranja,
        unselectedLabelColor: AppColors.textoSecundario,
        indicatorColor: AppColors.laranja,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textoSecundario,
        textColor: AppColors.textoPrimario,
      ),
    );
  }
}
