part of 'app_style.dart';

class AppTheme {
  final Color primary = const Color(0xFFFF0000);
  final Color secondary = const Color(0xFFFFDBDB);

  final Color background = const Color(0xFFF5F5F5);

  final Color caption = const Color(0xFF7D7873);
  final Color body = const Color(0xFF514F4D);
  final Color grey = const Color(0xFF272625);
  final Color border = const Color(0xFFCDCDCD);
  final Color ash = const Color(0xFF808080);
  final Color nu1 = const Color(0xFFABB3BB);
  final Color nu2 = const Color(0xFFD0D0D0);
  final Color nu3 = const Color(0xffF4F2F3);
  final Color divider = const Color(0xffD7D7D7);

  final Color white = Colors.white;
  final Color black = const Color(0xFF1E1B18);
  final Color red = const Color(0xffF05A5A);
  final Color green = const Color(0xff00CF00);
  final Color yellow = const Color(0xffFFC300);
  final Color text = const Color(0xFF000000);
  final Color textPrimary = const Color(0xFF092C4C);
  final Color transparent = Colors.transparent;

  final bool isDark = false;

  ThemeData data() {
    final textTheme = (isDark ? ThemeData.dark() : ThemeData.light()).textTheme;
    final InputBorder inputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: white, width: .9),
      borderRadius: BorderRadius.circular(styles.corners.sm),
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
      scaffoldBackgroundColor: background,
      highlightColor: primary,
      inputDecorationTheme: InputDecorationTheme(
        outlineBorder: const BorderSide(),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder,
        errorBorder: inputBorder,
        focusedErrorBorder: inputBorder,
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
