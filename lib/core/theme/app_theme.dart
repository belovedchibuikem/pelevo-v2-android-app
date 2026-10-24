import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Surfaces and text that switch with light and dark mode.
///
/// Brand colors stay on [PelevoColors]. Screens read this from the theme so a
/// light device is not painted with the dark palette.
class PelevoScheme extends ThemeExtension<PelevoScheme> {
  const PelevoScheme({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.textDim,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color textDim;

  static const dark = PelevoScheme(
    background: PelevoColors.background,
    surface: PelevoColors.surface,
    surfaceHigh: PelevoColors.surfaceHigh,
    border: PelevoColors.border,
    text: PelevoColors.text,
    textMuted: PelevoColors.textMuted,
    textDim: PelevoColors.textDim,
  );

  static const light = PelevoScheme(
    background: Color(0xFFF6F5F2),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEFEDE8),
    border: Color(0xFFD9D6D0),
    text: Color(0xFF161815),
    textMuted: Color(0xFF5E635E),
    textDim: Color(0xFF8B908B),
  );

  @override
  PelevoScheme copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? textDim,
  }) => PelevoScheme(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    border: border ?? this.border,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    textDim: textDim ?? this.textDim,
  );

  @override
  PelevoScheme lerp(PelevoScheme? other, double t) {
    if (other == null) return this;
    return PelevoScheme(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
    );
  }
}

extension PelevoSchemeContext on BuildContext {
  PelevoScheme get pelevo =>
      Theme.of(this).extension<PelevoScheme>() ?? PelevoScheme.dark;
}

abstract final class PelevoTheme {
  static ThemeData get dark => _theme(Brightness.dark, PelevoScheme.dark);

  static ThemeData get light => _theme(Brightness.light, PelevoScheme.light);

  static ThemeData _theme(Brightness brightness, PelevoScheme scheme) {
    final baseText = GoogleFonts.robotoCondensedTextTheme(
      brightness == Brightness.dark
          ? ThemeData.dark().textTheme
          : ThemeData.light().textTheme,
    ).apply(bodyColor: scheme.text, displayColor: scheme.text);
    final overlay = brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.background,
      canvasColor: scheme.background,
      extensions: [scheme],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: PelevoColors.red,
        onPrimary: Colors.white,
        secondary: PelevoColors.green,
        onSecondary: Colors.white,
        tertiary: PelevoColors.yellow,
        onTertiary: Colors.black,
        error: PelevoColors.red,
        onError: Colors.white,
        surface: scheme.surface,
        onSurface: scheme.text,
        outline: scheme.text,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.text,
          side: BorderSide(color: scheme.text, width: 1.5),
        ),
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
          color: scheme.textMuted,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerColor: scheme.border,
      dividerTheme: DividerThemeData(color: scheme.border),
      dialogTheme: DialogThemeData(backgroundColor: scheme.surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: scheme.surface),
      cardTheme: CardThemeData(color: scheme.surface),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceHigh,
        contentTextStyle: TextStyle(color: scheme.text, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        actionTextColor: PelevoColors.green,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.text,
        systemOverlayStyle: overlay.copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: scheme.textDim),
        labelStyle: TextStyle(color: scheme.textMuted),
        border: _inputBorder(scheme.border),
        enabledBorder: _inputBorder(scheme.border),
        focusedBorder: _inputBorder(PelevoColors.green),
        errorBorder: _inputBorder(PelevoColors.red),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.background,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10,
            color: states.contains(WidgetState.selected)
                ? PelevoColors.red
                : scheme.textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? PelevoColors.red
                : scheme.textMuted,
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
