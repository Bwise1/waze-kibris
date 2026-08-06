import 'package:flutter/material.dart';
import 'package:waze_kibris/app/dashboard/services/voice_instruction_service.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/services/map_style_preference.dart';
import 'package:waze_kibris/core/services/nav_puck_preference.dart';
import 'package:waze_kibris/core/services/nav_settings.dart';
import 'package:waze_kibris/core/services/puck_icon_factory.dart';

class DrivingPreferenceScreen extends StatelessWidget {
  const DrivingPreferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          AppHeader(
            backIcon: Assets.icons.backArrow,
            isTransparent: true,
          ),
          // Expanded gives the scroll view a bounded height. Without it the
          // Column hands it an unbounded main-axis constraint, so it sizes
          // itself to its content, never scrolls, and overflows the screen.
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Gap(16 * styles.scale),
                  Text(
                    'Driving preference',
                    style: styles.typography.h3.textColor(styles.theme.text),
                  ),
                  Gap(8 * styles.scale),
                  Text(
                    '''
Select things you want to see while driving to have the perfect experience''',
                    style:
                        styles.typography.hairline.textColor(styles.theme.ash),
                  ),
                  Gap(16 * styles.scale),
                  Text(
                    'Map style',
                    style:
                        styles.typography.h4
                            .textColor(styles.theme.text)
                            // h4 carries caps letter-spacing; sentence-case
                            // headings read better without it.
                            .copyWith(letterSpacing: 0),
                  ),
                  Gap(8 * styles.scale),
                  Text(
                    'Auto switches between day and night at sunset, like Waze.',
                    style:
                        styles.typography.hairline.textColor(styles.theme.ash),
                  ),
                  Gap(12 * styles.scale),
                  ValueListenableBuilder<MapStyleMode>(
                    valueListenable: MapStylePreference.mode,
                    builder: (context, mode, _) {
                      return SegmentedTab(
                        index: mode.index,
                        sections: const [
                          TabSection(label: 'Auto'),
                          TabSection(label: 'Day'),
                          TabSection(label: 'Night'),
                        ],
                        onTabPressed: (index) {
                          MapStylePreference.setMode(
                            MapStyleMode.values[index],
                          );
                        },
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(
                      color: styles.theme.secondary,
                      thickness: 1,
                    ),
                  ),
                  Text(
                    'Navigation icon',
                    style:
                        styles.typography.h4
                            .textColor(styles.theme.text)
                            // h4 carries caps letter-spacing; sentence-case
                            // headings read better without it.
                            .copyWith(letterSpacing: 0),
                  ),
                  Gap(8 * styles.scale),
                  Text(
                    'How you appear on the map while driving.',
                    style:
                        styles.typography.hairline.textColor(styles.theme.ash),
                  ),
                  Gap(12 * styles.scale),
                  const _PuckStylePicker(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(
                      color: styles.theme.secondary,
                      thickness: 1,
                    ),
                  ),
                  Text(
                    'Navigation voice',
                    style:
                        styles.typography.h4
                            .textColor(styles.theme.text)
                            // h4 carries caps letter-spacing; sentence-case
                            // headings read better without it.
                            .copyWith(letterSpacing: 0),
                  ),
                  Gap(8 * styles.scale),
                  Text(
                    'Pick the voice that reads turn-by-turn directions.',
                    style:
                        styles.typography.hairline.textColor(styles.theme.ash),
                  ),
                  Gap(4 * styles.scale),
                  const _VoicePickerTile(),
                  const _SectionDivider(),

                  // ── Voice guidance ──────────────────────────────────────
                  const _SectionTitle(
                    'Voice guidance',
                    subtitle: 'Spoken turn-by-turn directions while driving.',
                  ),
                  Gap(4 * styles.scale),
                  ValueListenableBuilder<bool>(
                    valueListenable: NavSettings.voiceEnabled,
                    builder: (context, enabled, _) => Column(
                      children: [
                        _SettingSwitch(
                          icon: enabled
                              ? Icons.volume_up_outlined
                              : Icons.volume_off_outlined,
                          label: 'Speak directions',
                          value: enabled,
                          onChanged: NavSettings.setVoiceEnabled,
                        ),
                        if (enabled)
                          ValueListenableBuilder<double>(
                            valueListenable: NavSettings.voiceVolume,
                            builder: (context, volume, _) => Row(
                              children: [
                                Icon(Icons.volume_mute,
                                    size: 18, color: styles.theme.ash),
                                Expanded(
                                  child: Slider(
                                    value: volume,
                                    onChanged: NavSettings.setVoiceVolume,
                                  ),
                                ),
                                Icon(Icons.volume_up,
                                    size: 18, color: styles.theme.ash),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const _SectionDivider(),

                  // ── Units ───────────────────────────────────────────────
                  const _SectionTitle(
                    'Distance units',
                    subtitle: 'Used for directions, ETA and the speedometer.',
                  ),
                  Gap(12 * styles.scale),
                  ValueListenableBuilder<DistanceUnit>(
                    valueListenable: NavSettings.units,
                    builder: (context, unit, _) => SegmentedTab(
                      index: unit.index,
                      sections: const [
                        TabSection(label: 'Kilometres'),
                        TabSection(label: 'Miles'),
                      ],
                      onTabPressed: (i) =>
                          NavSettings.setUnits(DistanceUnit.values[i]),
                    ),
                  ),
                  const _SectionDivider(),

                  // ── Route options ───────────────────────────────────────
                  const _SectionTitle(
                    'Route options',
                    subtitle: 'Applied to new routes and reroutes.',
                  ),
                  Gap(4 * styles.scale),
                  ValueListenableBuilder<bool>(
                    valueListenable: NavSettings.avoidTolls,
                    builder: (context, value, _) => _SettingSwitch(
                      icon: Icons.toll_outlined,
                      label: 'Avoid tolls',
                      value: value,
                      onChanged: NavSettings.setAvoidTolls,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: NavSettings.avoidHighways,
                    builder: (context, value, _) => _SettingSwitch(
                      icon: Icons.alt_route_outlined,
                      label: 'Avoid highways',
                      value: value,
                      onChanged: NavSettings.setAvoidHighways,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: NavSettings.avoidFerries,
                    builder: (context, value, _) => _SettingSwitch(
                      icon: Icons.directions_boat_outlined,
                      label: 'Avoid ferries',
                      value: value,
                      onChanged: NavSettings.setAvoidFerries,
                    ),
                  ),
                  const _SectionDivider(),

                  // ── Alerts & reports ────────────────────────────────────
                  const _SectionTitle(
                    'Alerts & reports',
                    subtitle: 'Choose what appears on your map.',
                  ),
                  Gap(4 * styles.scale),
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: NavSettings.mutedReportTypes,
                    builder: (context, muted, _) => Column(
                      children: [
                        for (final r in NavSettings.reportTypes)
                          _SettingSwitch(
                            icon: _reportIcon(r.type),
                            label: r.label,
                            value: !muted.contains(r.type),
                            onChanged: (v) =>
                                NavSettings.setReportTypeEnabled(r.type, v),
                          ),
                      ],
                    ),
                  ),
                  const _SectionDivider(),

                  // ── Display ─────────────────────────────────────────────
                  const _SectionTitle('While navigating'),
                  Gap(4 * styles.scale),
                  ValueListenableBuilder<bool>(
                    valueListenable: NavSettings.showSpeedometer,
                    builder: (context, value, _) => _SettingSwitch(
                      icon: Icons.speed_outlined,
                      label: 'Show speedometer',
                      value: value,
                      onChanged: NavSettings.setShowSpeedometer,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: NavSettings.keepScreenAwake,
                    builder: (context, value, _) => _SettingSwitch(
                      icon: Icons.screen_lock_portrait_outlined,
                      label: 'Keep screen awake',
                      value: value,
                      onChanged: NavSettings.setKeepScreenAwake,
                    ),
                  ),
                  Gap(24 * styles.scale),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft, friendly avatar palette in the same spirit as the preset profile
/// pictures — each voice gets its own tint so the list reads like a cast of
/// characters rather than a settings dump.
const List<({Color bg, Color fg})> _voiceAvatarColors = [
  (bg: Color(0xFFFFE3E3), fg: Color(0xFFD64545)), // brand red
  (bg: Color(0xFFE3EEFF), fg: Color(0xFF3A6FB0)), // blue
  (bg: Color(0xFFE6F5E9), fg: Color(0xFF3E8E53)), // green
  (bg: Color(0xFFFFF0DC), fg: Color(0xFFC97A20)), // amber
  (bg: Color(0xFFF0E7FA), fg: Color(0xFF7B54B0)), // violet
  (bg: Color(0xFFDDF2F3), fg: Color(0xFF2F8A8F)), // teal
];

/// Circular avatar for a voice: a flat male/female glyph on a tinted
/// background, matching the profile-picture presets' look.
class _VoiceAvatar extends StatelessWidget {
  const _VoiceAvatar({
    required this.isFemale,
    required this.colorIndex,
    this.size = 42,
  });

  final bool isFemale;
  final int colorIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = _voiceAvatarColors[colorIndex % _voiceAvatarColors.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: palette.bg, shape: BoxShape.circle),
      child: Icon(
        isFemale ? Icons.face_3 : Icons.face_6,
        size: size * 0.6,
        color: palette.fg,
      ),
    );
  }
}

/// "Female" / "Male" divider inside the voice sheet.
class _VoiceGroupLabel extends StatelessWidget {
  const _VoiceGroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: styles.typography.caption.textColor(styles.theme.ash),
      ),
    );
  }
}

/// Higher-fidelity voices are worth pointing out — they're the ones that
/// sound human. Plain "default" quality needs no note.
String? _qualityLabel(String quality) => switch (quality) {
      'premium' || 'very high' => 'Premium',
      'enhanced' || 'high' => 'Enhanced',
      _ => null,
    };

class _VoiceTile extends StatelessWidget {
  const _VoiceTile({
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final Widget leading;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? styles.theme.primary : styles.theme.text;
    return ListTile(
      leading: leading,
      title: Text(
        label,
        style: styles.typography.t3.textColor(color).copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: styles.typography.caption.textColor(styles.theme.ash),
            )
          : null,
      trailing: selected
          ? Icon(Icons.check_circle, color: styles.theme.primary, size: 22)
          : null,
      onTap: onTap,
    );
  }
}

IconData _reportIcon(String type) {
  switch (type) {
    case 'police':
      return Icons.local_police_outlined;
    case 'traffic':
      return Icons.traffic_outlined;
    case 'accident':
      return Icons.car_crash_outlined;
    case 'photo':
      return Icons.photo_camera_outlined;
    default:
      return Icons.warning_amber_outlined;
  }
}

/// Section heading + optional one-line explainer, in the page's type scale.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: styles.typography.h4
              .textColor(styles.theme.text)
              // h4 carries caps letter-spacing; sentence-case headings read
              // better without it.
              .copyWith(letterSpacing: 0),
        ),
        if (subtitle != null) ...[
          Gap(6 * styles.scale),
          Text(
            subtitle!,
            style: styles.typography.hairline.textColor(styles.theme.ash),
          ),
        ],
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(color: styles.theme.secondary, thickness: 1),
    );
  }
}

/// Icon + label + switch row, sized and coloured like the rest of settings.
class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: value ? styles.theme.primary : styles.theme.ash,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: styles.typography.t3.textColor(styles.theme.text),
              ),
            ),
            Switch.adaptive(
              value: value,
              activeTrackColor: styles.theme.primary,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// Arrow / car / bus / truck selector with live previews of the exact
/// artwork the map puck uses.
class _PuckStylePicker extends StatelessWidget {
  const _PuckStylePicker();

  static const _labels = {
    NavPuckStyle.arrow: 'Arrow',
    NavPuckStyle.car: 'Car',
    NavPuckStyle.bus: 'Bus',
    NavPuckStyle.truck: 'Truck',
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NavPuckStyle>(
      valueListenable: NavPuckPreference.style,
      builder: (context, selected, _) {
        return Row(
          children: [
            for (final style in NavPuckStyle.values) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => NavPuckPreference.setStyle(style),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      // Brand-pink fill for the active card, matching how
                      // selection reads elsewhere in the app.
                      color: style == selected
                          ? styles.theme.secondary.withValues(alpha: 0.45)
                          : styles.theme.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: style == selected
                            ? styles.theme.primary
                            : styles.theme.border,
                        width: style == selected ? 1.6 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: style == NavPuckStyle.arrow
                              ? Image.asset(
                                  'assets/icons/4.0x/CurrentPosition.png',
                                  fit: BoxFit.contain,
                                )
                              : CustomPaint(
                                  painter: PuckPreviewPainter(style),
                                ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _labels[style]!,
                          style: styles.typography.caption.textColor(
                            style == selected
                                ? styles.theme.primary
                                : styles.theme.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (style != NavPuckStyle.values.last) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}

/// Shows the active voice and opens the picker sheet.
class _VoicePickerTile extends StatelessWidget {
  const _VoicePickerTile();

  @override
  Widget build(BuildContext context) {
    final voiceService = VoiceInstructionService();
    return ValueListenableBuilder<String?>(
      valueListenable: voiceService.selectedVoiceName,
      builder: (context, name, _) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: styles.theme.secondary.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.record_voice_over,
                size: 22, color: styles.theme.primary),
          ),
          title: Text(name ?? 'System default',
              style: styles.typography.t3.textColor(styles.theme.text)),
          subtitle: Text(
            'Tap to change',
            style: styles.typography.caption.textColor(styles.theme.ash),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showVoiceSheet(context, voiceService),
        );
      },
    );
  }

  Future<void> _showVoiceSheet(
    BuildContext context,
    VoiceInstructionService voiceService,
  ) async {
    // Ensure the TTS engine exists even if navigation never started.
    await voiceService.initialize();
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: FutureBuilder<List<TtsVoiceOption>>(
            future: voiceService.availableVoices(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final voices = snapshot.data!;
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: Row(
                        children: [
                          Text('Navigation voice',
                              style: Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          Text(
                            'Tap to preview',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: styles.theme.ash),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ValueListenableBuilder<String?>(
                        valueListenable: voiceService.selectedVoiceName,
                        builder: (context, active, _) {
                          final females =
                              voices.where((v) => v.isFemale).toList();
                          final males =
                              voices.where((v) => !v.isFemale).toList();
                          return ListView(
                            shrinkWrap: true,
                            children: [
                              _VoiceTile(
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: styles.theme.nu3,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.smartphone,
                                      size: 22, color: styles.theme.body),
                                ),
                                label: 'System default',
                                selected: active == null,
                                onTap: voiceService.clearVoiceSelection,
                              ),
                              if (voices.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      20, 8, 20, 20),
                                  child: Text(
                                    'No natural-sounding voices are installed '
                                    'for English on this device. Add one in '
                                    'your phone settings under '
                                    'text-to-speech.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: styles.theme.ash),
                                  ),
                                ),
                              if (females.isNotEmpty)
                                const _VoiceGroupLabel('Female'),
                              for (final (i, voice) in females.indexed)
                                _VoiceTile(
                                  leading: _VoiceAvatar(
                                    isFemale: true,
                                    colorIndex: i,
                                  ),
                                  label: voice.displayName,
                                  subtitle: _qualityLabel(voice.quality),
                                  selected: active == voice.displayName,
                                  onTap: () => voiceService.selectVoice(voice),
                                ),
                              if (males.isNotEmpty)
                                const _VoiceGroupLabel('Male'),
                              for (final (i, voice) in males.indexed)
                                _VoiceTile(
                                  leading: _VoiceAvatar(
                                    isFemale: false,
                                    // Offset so the male row doesn't repeat
                                    // the same tints as the female row.
                                    colorIndex: i + 3,
                                  ),
                                  label: voice.displayName,
                                  subtitle: _qualityLabel(voice.quality),
                                  selected: active == voice.displayName,
                                  onTap: () => voiceService.selectVoice(voice),
                                ),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
