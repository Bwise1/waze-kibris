part of '../app_style.dart';

@immutable
class Typography {
  Typography(this._scale);
  final double _scale;

 
  final f =  GoogleFonts.poppins();
    late final TextStyle dropCase = _font(f, sz: 56, h: 20);

  late final TextStyle headline = _font(f, sz: 64, h: 56);

  late final TextStyle h1 = _font(f, sz: 64, h: 62);
  late final TextStyle h2 = _font(f, sz: 32, h: 46);
  late final TextStyle h3 = _font(f, sz: 20, h: 36, w: FontWeight.w600);
  late final TextStyle h4 = _font(f, sz: 18, h: 23, s: 5, w: FontWeight.w600);
  late final TextStyle h5 = _font(f, sz: 16, h: 26, w: FontWeight.w600);

  late final TextStyle t1 = _font(f, sz: 20, h: 26, s: 5);
  late final TextStyle t2 = _font(f, sz: 18, h: 16.38);
  late final TextStyle t3 = _font(f, sz: 16, h: 26);

  late final TextStyle body = _font(f, sz: 14, h: 26);

  late final TextStyle caption = _font(f, sz: 14, h: 20, w: FontWeight.w500)
      .copyWith(fontStyle: FontStyle.italic);

  late final TextStyle hairline = _font(f, sz: 12, h: 20, w: FontWeight.w400);

  late final TextStyle overline = _font(f, sz: 12, h: 16, w: FontWeight.w500);

  late final TextStyle callout = _font(f, sz: 16, h: 26, w: FontWeight.w600)
      .copyWith(fontStyle: FontStyle.italic);

  late final TextStyle btn = _font(f, sz: 18, w: FontWeight.w600, s: 2, h: 14);

  TextStyle _font(
    TextStyle sty, {
    required double sz,
    double? h,
    double? s,
    FontWeight? w,
  }) {
    sz *= _scale;
    if (h != null) {
      h *= _scale;
    }
    return sty.copyWith(
      fontSize: sz,
      height: h != null ? (h / sz) : sty.height,
      letterSpacing: s != null ? sz * s * 0.01 : sty.letterSpacing,
      fontWeight: w,
    );
  }
}
