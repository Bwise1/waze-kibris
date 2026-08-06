import 'dart:async';
import 'dart:developer' as developer;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';

/// One selectable navigation voice, already filtered down to natural-sounding
/// options with a known gender (see [VoiceInstructionService.availableVoices]).
class TtsVoiceOption {
  const TtsVoiceOption({
    required this.name,
    required this.locale,
    required this.gender,
    required this.displayName,
    this.quality = '',
  });

  final String name;
  final String locale;

  /// 'female' or 'male' — never empty for voices we surface.
  final String gender;

  /// What the picker shows, e.g. "Female voice 1".
  final String displayName;

  /// Platform quality tier; used only to prefer the better duplicate.
  final String quality;

  bool get isFemale => gender == 'female';
}

class _VoiceCandidate {
  const _VoiceCandidate({
    required this.name,
    required this.locale,
    required this.gender,
    required this.quality,
    required this.rank,
  });

  final String name;
  final String locale;
  final String gender;
  final String quality;
  final int rank;

  TtsVoiceOption toOption(String displayName) => TtsVoiceOption(
        name: name,
        locale: locale,
        gender: gender,
        quality: quality,
        displayName: displayName,
      );
}

class VoiceInstructionService {
  static final VoiceInstructionService _instance =
      VoiceInstructionService._internal();
  factory VoiceInstructionService() => _instance;
  VoiceInstructionService._internal();

  FlutterTts? _flutterTts;
  AudioSession? _audioSession;
  bool _isEnabled = true;
  bool _isSpeaking = false;
  String _language = 'en-US';
  double _speechRate = 0.5;
  double _volume = 1.0;
  double _pitch = 1.0;

  // Track announced instructions to avoid repeating
  final Set<String> _announcedInstructions = <String>{};

  static const String _voiceNameKey = 'tts_voice_name';
  static const String _voiceLocaleKey = 'tts_voice_locale';
  static const String _voiceLabelKey = 'tts_voice_label';

  /// Display name of the user-selected voice (null = system default).
  /// Listen from settings UI.
  final ValueNotifier<String?> selectedVoiceName = ValueNotifier(null);

  Future<void> initialize() async {
    if (_flutterTts != null) return; // singleton — already initialized
    _flutterTts = FlutterTts();

    if (_flutterTts != null) {
      await _flutterTts!.setLanguage(_language);
      await _flutterTts!.setSpeechRate(_speechRate);
      await _flutterTts!.setVolume(_volume);
      await _flutterTts!.setPitch(_pitch);
      await _applyPersistedVoice();

      // Set up callbacks
      _flutterTts!.setStartHandler(() {
        _isSpeaking = true;
        developer.log('Voice instruction started',
            name: 'VoiceInstructionService');
      });

      _flutterTts!.setCompletionHandler(() async {
        _isSpeaking = false;
        await _audioSession?.setActive(false);
        developer.log('Voice instruction completed',
            name: 'VoiceInstructionService');
      });

      _flutterTts!.setErrorHandler((msg) async {
        _isSpeaking = false;
        await _audioSession?.setActive(false);
        developer.log('Voice instruction error: $msg',
            name: 'VoiceInstructionService');
      });

      // Configure audio session for navigation: duck background media during TTS
      try {
        _audioSession = await AudioSession.instance;
        await _audioSession!.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ));
      } catch (e) {
        developer.log('Audio session configuration failed: $e',
            name: 'VoiceInstructionService');
      }

      developer.log('Voice instruction service initialized',
          name: 'VoiceInstructionService');
    }
  }

  Future<void> dispose() async {
    await _flutterTts?.stop();
    _flutterTts = null;
  }

  // Process voice instructions for a step based on distance remaining
  Future<void> processVoiceInstructions(
    MapboxStep step,
    double distanceRemaining,
  ) async {
    if (!_isEnabled || _flutterTts == null || step.voiceInstructions.isEmpty) {
      return;
    }

    // Mapbox orders a step's voice instructions farthest-first (e.g. 800m,
    // 200m, 30m). An instruction is "due" once distanceRemaining drops to
    // its trigger distance. Pick the MOST SPECIFIC due instruction that
    // hasn't been announced yet (smallest distanceAlongGeometry) — picking
    // the first list match would select the farthest one every tick and the
    // close-in "Turn right now" would never be spoken.
    MapboxVoiceInstruction? instructionToSpeak;

    for (final instruction in step.voiceInstructions) {
      final isDue =
          distanceRemaining <= instruction.distanceAlongGeometry + 10;
      if (!isDue) continue;
      if (_announcedInstructions.contains(_keyFor(instruction))) continue;
      if (instructionToSpeak == null ||
          instruction.distanceAlongGeometry <
              instructionToSpeak.distanceAlongGeometry) {
        instructionToSpeak = instruction;
      }
    }

    if (instructionToSpeak != null) {
      // Mark every due-but-stale sibling as announced so a far instruction
      // we skipped (e.g. app was mid-utterance) doesn't play late, after
      // the closer one.
      for (final instruction in step.voiceInstructions) {
        if (instruction.distanceAlongGeometry >=
            instructionToSpeak.distanceAlongGeometry &&
            distanceRemaining <= instruction.distanceAlongGeometry + 10) {
          _announcedInstructions.add(_keyFor(instruction));
        }
      }
      await _speakInstruction(instructionToSpeak);
    }
  }

  String _keyFor(MapboxVoiceInstruction instruction) =>
      '${instruction.distanceAlongGeometry}-${instruction.announcement}';

  Future<void> _speakInstruction(MapboxVoiceInstruction instruction) async {
    try {
      // A newly due instruction is always more urgent than whatever is
      // still playing — cut the old one off rather than dropping the new
      // one ("Turn right now" must not lose to "In 400 meters...").
      if (_isSpeaking) {
        await _flutterTts!.stop();
        _isSpeaking = false;
      }

      await _audioSession?.setActive(true);

      // Always speak the plain-text announcement. flutter_tts's speak()
      // does not parse SSML — passing ssmlAnnouncement makes the engine
      // read the markup tags aloud.
      final textToSpeak = instruction.announcement;

      developer.log('Speaking: $textToSpeak', name: 'VoiceInstructionService');

      await _flutterTts!.speak(textToSpeak);
    } catch (e) {
      developer.log('Error speaking instruction: $e',
          name: 'VoiceInstructionService');
    }
  }

  /// Speak a plain text phrase (e.g. "Rerouting" when user goes off-route).
  Future<void> speak(String text) async {
    if (!_isEnabled || _flutterTts == null || text.isEmpty) return;
    try {
      await _audioSession?.setActive(true);
      await _flutterTts!.speak(text);
    } catch (e) {
      developer.log('Error speaking: $e', name: 'VoiceInstructionService');
    }
  }

  // Manual voice instruction trigger (for voice button)
  Future<void> speakCurrentInstruction(MapboxStep step) async {
    if (!_isEnabled || _flutterTts == null) return;

    // Stop current speech
    await stop();

    // Speak the most recent voice instruction or fallback to maneuver instruction
    String textToSpeak;

    if (step.voiceInstructions.isNotEmpty) {
      // Plain-text announcement only — flutter_tts does not parse SSML.
      textToSpeak = step.voiceInstructions.first.announcement;
    } else {
      textToSpeak = step.maneuver.instruction;
    }

    try {
      await _audioSession?.setActive(true);
      developer.log('Manual speech: $textToSpeak',
          name: 'VoiceInstructionService');
      await _flutterTts!.speak(textToSpeak);
    } catch (e) {
      developer.log('Error in manual speech: $e',
          name: 'VoiceInstructionService');
    }
  }

  Future<void> stop() async {
    if (_flutterTts != null && _isSpeaking) {
      await _flutterTts!.stop();
    }
  }

  // Reset announced instructions (call when starting new navigation)
  void reset() {
    _announcedInstructions.clear();
    stop();
  }

  /// Prepare audio session for a new navigation session so the first utterance is less likely to be missed.
  Future<void> prepareForNavigation() async {
    try {
      await _audioSession?.setActive(true);
    } catch (e) {
      developer.log('Error preparing audio session for navigation: $e',
          name: 'VoiceInstructionService');
    }
  }

  /// Clear announced instructions for the new step (call when advancing step so new step's announcements can play).
  void clearAnnouncedInstructionsForNewStep() {
    _announcedInstructions.clear();
  }

  // Settings
  bool get isEnabled => _isEnabled;
  bool get isSpeaking => _isSpeaking;

  set isEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      stop();
    }
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    await _flutterTts?.setLanguage(language);
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.0, 1.0);
    await _flutterTts?.setSpeechRate(_speechRate);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _flutterTts?.setVolume(_volume);
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _flutterTts?.setPitch(_pitch);
  }

  // Get available languages
  Future<List<dynamic>> getLanguages() async {
    final languages = await _flutterTts?.getLanguages;
    if (languages == null) return <dynamic>[];
    return List<dynamic>.from(languages as Iterable<dynamic>);
  }

  // ── Voice selection ──────────────────────────────────────────────────────

  /// iOS/macOS novelty and legacy "Eloquence" voices. They are installed by
  /// default and sound synthetic or comedic — never appropriate for driving
  /// directions, so they are filtered out entirely.
  static const Set<String> _noveltyVoices = {
    'albert', 'bad news', 'bahh', 'bells', 'boing', 'bubbles', 'cellos',
    'deranged', 'eddy', 'flo', 'fred', 'good news', 'grandma', 'grandpa',
    'jester', 'junior', 'kathy', 'organ', 'ralph', 'reed', 'rocko', 'sandy',
    'shelley', 'superstar', 'trinoids', 'whisper', 'wobble', 'zarvox',
    'zuzana', 'agnes', 'princess', 'hysterical',
  };

  /// Google TTS on Android exposes no gender field — only opaque names like
  /// `en-us-x-tpf-local`. These are the documented-by-convention gender codes
  /// for the standard English voice packs; anything not listed is skipped
  /// rather than guessed at.
  static const Map<String, String> _androidVoiceGenders = {
    'tpf': 'female', 'tpc': 'female', 'sfg': 'female', 'iob': 'female',
    'iol': 'female', 'gbb': 'female', 'gbc': 'female', 'apf': 'female',
    'tpd': 'male', 'iom': 'male', 'iog': 'male', 'gbd': 'male',
    'gba': 'male', 'apa': 'male',
  };

  /// A short, curated list of natural voices for the current language:
  /// a few female and a few male, best quality first, no robotic ones.
  Future<List<TtsVoiceOption>> availableVoices() async {
    final tts = _flutterTts;
    if (tts == null) return const [];
    try {
      final raw = await tts.getVoices;
      if (raw is! Iterable) return const [];
      final langPrefix = _language.split('-').first.toLowerCase();

      final candidates = <_VoiceCandidate>[];
      for (final v in raw) {
        if (v is! Map) continue;
        final name = v['name']?.toString() ?? '';
        final locale = v['locale']?.toString() ?? '';
        if (name.isEmpty || locale.isEmpty) continue;
        if (!locale.toLowerCase().startsWith(langPrefix)) continue;

        final quality = v['quality']?.toString().toLowerCase() ?? '';
        var gender = v['gender']?.toString().toLowerCase() ?? '';

        if (name.contains('-x-')) {
          // Android: derive gender from the voice-pack code.
          final code = name.split('-x-').last.split('-').first.toLowerCase();
          gender = _androidVoiceGenders[code] ?? '';
          // Skip low-quality packs — these are the "robot" ones.
          if (quality == 'low' || quality == 'very low') continue;
        } else {
          // iOS: drop the novelty/Eloquence family outright.
          final bare = name.toLowerCase().split('(').first.trim();
          if (_noveltyVoices.contains(bare)) continue;
        }

        // Without a known gender we can't label it honestly — skip it.
        if (gender != 'female' && gender != 'male') continue;

        candidates.add(_VoiceCandidate(
          name: name,
          locale: locale,
          gender: gender,
          quality: quality,
          rank: _qualityRank(quality),
        ));
      }

      // Best variant wins per underlying voice (iOS lists Compact/Enhanced/
      // Premium of the same person; Android local vs network).
      final bestByVoice = <String, _VoiceCandidate>{};
      for (final c in candidates) {
        final key = c.name.contains('-x-')
            ? c.name.split('-x-').last.split('-').first.toLowerCase()
            : c.name.toLowerCase().split('(').first.trim();
        final existing = bestByVoice[key];
        if (existing == null || c.rank > existing.rank) bestByVoice[key] = c;
      }

      final females = bestByVoice.values.where((c) => c.gender == 'female')
          .toList()
        ..sort((a, b) => b.rank.compareTo(a.rank));
      final males = bestByVoice.values.where((c) => c.gender == 'male').toList()
        ..sort((a, b) => b.rank.compareTo(a.rank));

      const perGender = 3;
      final picked = <TtsVoiceOption>[];
      for (var i = 0; i < females.length && i < perGender; i++) {
        picked.add(females[i].toOption(_labelFor(females[i], i)));
      }
      for (var i = 0; i < males.length && i < perGender; i++) {
        picked.add(males[i].toOption(_labelFor(males[i], i)));
      }
      return picked;
    } catch (e) {
      developer.log('getVoices failed: $e', name: 'VoiceInstructionService');
      return const [];
    }
  }

  static int _qualityRank(String quality) => switch (quality) {
        'premium' || 'very high' => 3,
        'enhanced' || 'high' => 2,
        'default' || 'normal' => 1,
        _ => 0,
      };

  /// Voice names the platform actually gives us are the friendliest label —
  /// iOS reports real ones ("Tessa", "Daniel"), so keep them and just drop
  /// the "(Enhanced)" / "(Premium)" suffix. Android only has opaque pack
  /// codes, so those fall back to a numbered label.
  static String _labelFor(_VoiceCandidate candidate, int index) {
    if (!candidate.name.contains('-x-')) {
      final bare = candidate.name.split('(').first.trim();
      if (bare.isNotEmpty) return bare;
    }
    final genderLabel = candidate.gender == 'female' ? 'Female' : 'Male';
    return '$genderLabel voice ${index + 1}';
  }

  /// Select and persist a voice; speaks a short sample so the user hears it.
  Future<void> selectVoice(TtsVoiceOption voice) async {
    try {
      await _flutterTts
          ?.setVoice({'name': voice.name, 'locale': voice.locale});
      selectedVoiceName.value = voice.displayName;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_voiceNameKey, voice.name);
      await prefs.setString(_voiceLocaleKey, voice.locale);
      await prefs.setString(_voiceLabelKey, voice.displayName);
      await speak('This is your new navigation voice');
    } catch (e) {
      developer.log('setVoice failed: $e', name: 'VoiceInstructionService');
    }
  }

  /// Back to the engine's default voice for the language.
  Future<void> clearVoiceSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_voiceNameKey);
      await prefs.remove(_voiceLocaleKey);
      await prefs.remove(_voiceLabelKey);
      selectedVoiceName.value = null;
      // Re-asserting the language resets the engine to its default voice.
      await _flutterTts?.setLanguage(_language);
      await speak('This is the default navigation voice');
    } catch (e) {
      developer.log('clearVoice failed: $e', name: 'VoiceInstructionService');
    }
  }

  Future<void> _applyPersistedVoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_voiceNameKey);
      final locale = prefs.getString(_voiceLocaleKey);
      if (name == null || locale == null) return;
      await _flutterTts?.setVoice({'name': name, 'locale': locale});
      selectedVoiceName.value = prefs.getString(_voiceLabelKey);
    } catch (e) {
      developer.log('applying persisted voice failed: $e',
          name: 'VoiceInstructionService');
    }
  }

  // Test speech
  Future<void> testSpeech() async {
    if (_isEnabled && _flutterTts != null) {
      await _audioSession?.setActive(true);
      await _flutterTts!.speak('Voice instructions are working correctly');
    }
  }
}
