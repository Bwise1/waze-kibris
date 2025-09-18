import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';

class VoiceInstructionService {
  static final VoiceInstructionService _instance =
      VoiceInstructionService._internal();
  factory VoiceInstructionService() => _instance;
  VoiceInstructionService._internal();

  FlutterTts? _flutterTts;
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

      _flutterTts!.setCompletionHandler(() {
        _isSpeaking = false;
        developer.log('Voice instruction completed',
            name: 'VoiceInstructionService');
      });

      _flutterTts!.setErrorHandler((msg) {
        _isSpeaking = false;
        developer.log('Voice instruction error: $msg',
            name: 'VoiceInstructionService');
      });

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
  Future getLanguages() async {
    return await _flutterTts?.getLanguages ?? [];
  }

  // Test speech
  Future<void> testSpeech() async {
    if (_isEnabled && _flutterTts != null) {
      await _flutterTts!.speak('Voice instructions are working correctly');
    }
  }
}
