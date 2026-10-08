import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class PelevoColors {
  static const background = Color(0xFF030504);
  static const surface = Color(0xFF101211);
  static const surfaceHigh = Color(0xFF191B1A);
  static const border = Color(0xFF303331);
  static const text = Color(0xFFF7F7F4);
  static const textMuted = Color(0xFFAAAFAA);
  static const textDim = Color(0xFF6F746F);
  static const red = Color(0xFFED1C2B);
  static const redDark = Color(0xFF9C101B);
  static const green = Color(0xFF2FA44F);
  static const greenDark = Color(0xFF176B35);
  static const yellow = Color(0xFFFFBE16);
  static const blue = Color(0xFF287BE0);
  static const orange = Color(0xFFF36F21);
  static const purple = Color(0xFF9B5CFF);
  static const pink = Color(0xFFE05CA8);
}

abstract final class PelevoSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const page = 20.0;
}

abstract final class PelevoRadii {
  static const small = 6.0;
  static const medium = 9.0;
  static const large = 14.0;
  static const card = BorderRadius.all(Radius.circular(medium));
}

abstract final class PelevoMotion {
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 480);
}

abstract final class PelevoTheme {
  static ThemeData get dark {
    final baseText = GoogleFonts.robotoCondensedTextTheme(
      ThemeData.dark().textTheme,
    ).apply(bodyColor: PelevoColors.text, displayColor: PelevoColors.text);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: PelevoColors.background,
      canvasColor: PelevoColors.background,
      colorScheme: const ColorScheme.dark(
        primary: PelevoColors.red,
        secondary: PelevoColors.green,
        tertiary: PelevoColors.yellow,
        surface: PelevoColors.surface,
        error: PelevoColors.red,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.black,
        onSurface: PelevoColors.text,
      ),
      textTheme: baseText.copyWith(
        displaySmall: baseText.displaySmall?.copyWith(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          height: 1.05,
        ),
        headlineLarge: baseText.headlineLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.12,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 16, height: 1.4),
        bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
        bodySmall: baseText.bodySmall?.copyWith(
          fontSize: 12,
          height: 1.35,
          color: PelevoColors.textMuted,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerColor: PelevoColors.border,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: PelevoColors.border,
        contentTextStyle: TextStyle(color: PelevoColors.text, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        actionTextColor: PelevoColors.green,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: PelevoColors.text,
        titleTextStyle: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PelevoColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: PelevoColors.textDim),
        labelStyle: const TextStyle(color: PelevoColors.textMuted),
        border: _inputBorder(PelevoColors.border),
        enabledBorder: _inputBorder(PelevoColors.border),
        focusedBorder: _inputBorder(PelevoColors.green),
        errorBorder: _inputBorder(PelevoColors.red),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: PelevoColors.background,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10,
            color:
                states.contains(WidgetState.selected)
                    ? PelevoColors.red
                    : PelevoColors.textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color:
                states.contains(WidgetState.selected)
                    ? PelevoColors.red
                    : PelevoColors.textMuted,
          ),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(PelevoRadii.small),
    borderSide: BorderSide(color: color),
  );
}
