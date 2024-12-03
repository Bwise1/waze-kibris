part of 'app_style.dart';

class AppTheme {
  final Color primary = const Color(0xFFFFCF57);
  final Color secondary = const Color(0xFFFF6A44);
  final Color background = const Color(0xFFF8ECE5);

  final Color caption = const Color(0xFF7D7873);
  final Color body = const Color(0xFF514F4D);
  final Color grey = const Color(0xFF272625);
  final Color ash = const Color(0xFF9D9995);
  final Color nu1 = const Color(0xFFABB3BB);
  final Color nu2 = const Color(0xFFD0D0D0);
  final Color nu3 = const Color(0xffE0E0E0);

  final Color white = Colors.white;
  final Color black = const Color(0xFF1E1B18);
  final Color red = const Color(0xffF05A5A);
  final Color text = const Color(0xFF54480C);
  final Color textPrimary = const Color(0xFF092C4C);

  final bool isDark = false;

  ThemeData data() {
    final textTheme =
        (isDark ? ThemeData.dark() : ThemeData.light()).textTheme;
    final InputBorder inputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: nu2, width: .9),
      borderRadius: BorderRadius.circular(styles.corners.md),
    );

    final txtColor = text;
    final scheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: white,
      primaryContainer: primary,
      secondary: secondary,
      secondaryContainer: primary,
      surface: white,
      onSurface: txtColor,
      onError: white,
      onPrimary: white,
      onSecondary: white,
      error: red,
    );

    return ThemeData.from(textTheme: textTheme, colorScheme: scheme).copyWith(
      textSelectionTheme: TextSelectionThemeData(cursorColor: primary),
      scaffoldBackgroundColor: white,
      highlightColor: primary,
      inputDecorationTheme: InputDecorationTheme(
        outlineBorder: const BorderSide(),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: textPrimary, width: .9),
        ),
        errorBorder:
            inputBorder.copyWith(borderSide: BorderSide(color: red, width: .9)),
        focusedErrorBorder:
            inputBorder.copyWith(borderSide: BorderSide(color: red, width: .9)),
        disabledBorder: inputBorder,
        fillColor: scheme.surface,
        hoverColor: scheme.surface,
        contentPadding: const EdgeInsets.all(12),
        errorStyle: textTheme.bodyMedium!.copyWith(color: red),
        alignLabelWithHint: true,
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
