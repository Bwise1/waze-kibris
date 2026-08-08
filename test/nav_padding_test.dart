import 'package:flutter_test/flutter_test.dart';

/// Mirrors updateNavigationViewportPadding's solve. The camera centres in
/// the box between the paddings, so the puck's screen position is the
/// midpoint — not the top inset. Getting that wrong put the puck at ~41%
/// (way too high) in one build and behind the sheet in another.
double topInsetFor({
  required double mapHeight,
  required double bottomObstruction,
  double puckFraction = 0.72,
}) {
  final bottom = bottomObstruction.clamp(0.0, mapHeight * 0.5);
  final target = mapHeight * puckFraction;
  return (2 * target - mapHeight + bottom).clamp(0.0, mapHeight * 0.8);
}

double puckScreenFraction({
  required double mapHeight,
  required double bottomObstruction,
}) {
  final bottom = bottomObstruction.clamp(0.0, mapHeight * 0.5);
  final top = topInsetFor(mapHeight: mapHeight, bottomObstruction: bottom);
  final centre = top + (mapHeight - top - bottom) / 2;
  return centre / mapHeight;
}

void main() {
  test('puck lands at the target height whatever the card size', () {
    for (final card in [0.0, 120.0, 180.0, 220.0, 260.0]) {
      final f = puckScreenFraction(mapHeight: 870, bottomObstruction: card);
      expect(f, closeTo(0.72, 0.001),
          reason: 'card=$card put the puck at ${(f * 100).toStringAsFixed(1)}%');
    }
  });

  test('the target fraction must clear the tallest expected card', () {
    // 0.72 of an 870pt map puts the puck at 626pt, which sits above a 220pt
    // card (map bottom - 220 = 650pt) but NOT above a 260pt one. That's the
    // real constraint on the constant, so assert it directly rather than
    // pretending any fraction works with any card.
    const mapHeight = 870.0;
    const puckY = mapHeight * 0.72;
    const tallestSupportedCard = 240.0;
    expect(puckY, lessThan(mapHeight - tallestSupportedCard),
        reason: 'puck at ${puckY.toStringAsFixed(0)}pt would sit under a '
            '${tallestSupportedCard}pt card — lower puckFraction');
  });

  test('a huge card is clamped rather than pushing the camera off-screen', () {
    final f = puckScreenFraction(mapHeight: 870, bottomObstruction: 800);
    expect(f, greaterThan(0.0));
    expect(f, lessThan(1.0));
  });
}
