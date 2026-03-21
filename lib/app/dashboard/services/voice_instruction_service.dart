import 'dart:async';
import 'dart:developer' as developer;
import 'package:audio_session/audio_session.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';

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

  Future<void> initialize() async {
    _flutterTts = FlutterTts();

    if (_flutterTts != null) {
      await _flutterTts!.setLanguage(_language);
      await _flutterTts!.setSpeechRate(_speechRate);
      await _flutterTts!.setVolume(_volume);
      await _flutterTts!.setPitch(_pitch);

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

    // Find the appropriate voice instruction based on distance
    MapboxVoiceInstruction? instructionToSpeak;

    for (final instruction in step.voiceInstructions) {
      // Trigger instruction if we're at or past the trigger distance
      if (distanceRemaining <= instruction.distanceAlongGeometry + 10) {
        // 10m tolerance
        instructionToSpeak = instruction;
        break;
      }
    }

    if (instructionToSpeak != null) {
      await _speakInstruction(instructionToSpeak);
    }
  }

  Future<void> _speakInstruction(MapboxVoiceInstruction instruction) async {
    // Create unique key for this instruction to avoid repeating
    final instructionKey =
        '${instruction.distanceAlongGeometry}-${instruction.announcement}';

    if (_announcedInstructions.contains(instructionKey) || _isSpeaking) {
      return;
    }

    _announcedInstructions.add(instructionKey);

    try {
      await _audioSession?.setActive(true);

      // Use SSML if available for better pronunciation, otherwise use plain text
      final textToSpeak =
          instruction.ssmlAnnouncement ?? instruction.announcement;

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
      final latestInstruction = step.voiceInstructions.first;
      textToSpeak =
          latestInstruction.ssmlAnnouncement ?? latestInstruction.announcement;
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

  // Test speech
  Future<void> testSpeech() async {
    if (_isEnabled && _flutterTts != null) {
      await _audioSession?.setActive(true);
      await _flutterTts!.speak('Voice instructions are working correctly');
    }
  }
}
