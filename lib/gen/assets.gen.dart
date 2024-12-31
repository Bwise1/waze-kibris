/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: directives_ordering,unnecessary_import,implicit_dynamic_list_literal,deprecated_member_use

import 'package:flutter/widgets.dart';

class $AssetsIconsGen {
  const $AssetsIconsGen();

  /// File path: assets/icons/accident.svg
  String get accident => 'assets/icons/accident.svg';

  /// File path: assets/icons/apple.svg
  String get apple => 'assets/icons/apple.svg';

  /// File path: assets/icons/arrow_forward.svg
  String get arrowForward => 'assets/icons/arrow_forward.svg';

  /// File path: assets/icons/at.svg
  String get at => 'assets/icons/at.svg';

  /// File path: assets/icons/back_arrow.svg
  String get backArrow => 'assets/icons/back_arrow.svg';

  /// File path: assets/icons/bin.svg
  String get bin => 'assets/icons/bin.svg';

  /// File path: assets/icons/briefcase.svg
  String get briefcase => 'assets/icons/briefcase.svg';

  /// File path: assets/icons/chat.svg
  String get chat => 'assets/icons/chat.svg';

  /// File path: assets/icons/close.svg
  String get close => 'assets/icons/close.svg';

  /// File path: assets/icons/coordinate.svg
  String get coordinate => 'assets/icons/coordinate.svg';

  /// File path: assets/icons/double_arrow.svg
  String get doubleArrow => 'assets/icons/double_arrow.svg';

  /// File path: assets/icons/flag_marker.svg
  String get flagMarker => 'assets/icons/flag_marker.svg';

  /// File path: assets/icons/globe.svg
  String get globe => 'assets/icons/globe.svg';

  /// File path: assets/icons/google.svg
  String get google => 'assets/icons/google.svg';

  /// File path: assets/icons/home.svg
  String get home => 'assets/icons/home.svg';

  /// File path: assets/icons/home_smile.svg
  String get homeSmile => 'assets/icons/home_smile.svg';

  /// File path: assets/icons/light.svg
  String get light => 'assets/icons/light.svg';

  /// File path: assets/icons/location.svg
  String get location => 'assets/icons/location.svg';

  /// File path: assets/icons/map_marker.svg
  String get mapMarker => 'assets/icons/map_marker.svg';

  /// File path: assets/icons/moon.svg
  String get moon => 'assets/icons/moon.svg';

  /// File path: assets/icons/person.svg
  String get person => 'assets/icons/person.svg';

  /// File path: assets/icons/plus.svg
  String get plus => 'assets/icons/plus.svg';

  /// File path: assets/icons/police.svg
  String get police => 'assets/icons/police.svg';

  /// File path: assets/icons/profile.svg
  String get profile => 'assets/icons/profile.svg';

  /// File path: assets/icons/route_logo.svg
  String get routeLogo => 'assets/icons/route_logo.svg';

  /// File path: assets/icons/route_logo_text.svg
  String get routeLogoText => 'assets/icons/route_logo_text.svg';

  /// File path: assets/icons/search_glass.svg
  String get searchGlass => 'assets/icons/search_glass.svg';

  /// File path: assets/icons/sending.svg
  String get sending => 'assets/icons/sending.svg';

  /// File path: assets/icons/shield_zap.svg
  String get shieldZap => 'assets/icons/shield_zap.svg';

  /// File path: assets/icons/traffic.svg
  String get traffic => 'assets/icons/traffic.svg';

  /// List of all assets
  List<String> get values => [
        accident,
        apple,
        arrowForward,
        at,
        backArrow,
        bin,
        briefcase,
        chat,
        close,
        coordinate,
        doubleArrow,
        flagMarker,
        globe,
        google,
        home,
        homeSmile,
        light,
        location,
        mapMarker,
        moon,
        person,
        plus,
        police,
        profile,
        routeLogo,
        routeLogoText,
        searchGlass,
        sending,
        shieldZap,
        traffic
      ];
}

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// File path: assets/images/Frame 2023.png
  AssetGenImage get frame2023 =>
      const AssetGenImage('assets/images/Frame 2023.png');

  /// File path: assets/images/intro-gradient.png
  AssetGenImage get introGradientPng =>
      const AssetGenImage('assets/images/intro-gradient.png');

  /// File path: assets/images/intro-gradient.svg
  String get introGradientSvg => 'assets/images/intro-gradient.svg';

  /// File path: assets/images/route_3d.png
  AssetGenImage get route3d =>
      const AssetGenImage('assets/images/route_3d.png');

  /// File path: assets/images/routemap_3d.png
  AssetGenImage get routemap3d =>
      const AssetGenImage('assets/images/routemap_3d.png');

  /// File path: assets/images/splash_background.png
  AssetGenImage get splashBackground =>
      const AssetGenImage('assets/images/splash_background.png');

  /// List of all assets
  List<dynamic> get values => [
        frame2023,
        introGradientPng,
        introGradientSvg,
        route3d,
        routemap3d,
        splashBackground
      ];
}

class Assets {
  Assets._();

  static const $AssetsIconsGen icons = $AssetsIconsGen();
  static const $AssetsImagesGen images = $AssetsImagesGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
  });

  final String _assetName;

  final Size? size;
  final Set<String> flavors;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.low,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({
    AssetBundle? bundle,
    String? package,
  }) {
    return AssetImage(
      _assetName,
      bundle: bundle,
      package: package,
    );
  }

  String get path => _assetName;

  String get keyName => _assetName;
}
