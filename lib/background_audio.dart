import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

class BackgroundAudio with WidgetsBindingObserver {
  BackgroundAudio._();

  static final BackgroundAudio instance = BackgroundAudio._();

  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _resumeAfterFocusLoss = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(0.4);
    _isInitialized = true;
  }

  Future<void> play() async {
    await initialize();
    if (_isPlaying) {
      return;
    }
    await _player.play(AssetSource('audio/hidup_jokowi.mp3'));
    _isPlaying = true;
  }

  Future<void> pause() async {
    if (!_isInitialized || !_isPlaying) {
      return;
    }
    await _player.pause();
    _isPlaying = false;
  }

  Future<void> stop() async {
    if (!_isInitialized) {
      return;
    }
    await _player.stop();
    _isPlaying = false;
    _resumeAfterFocusLoss = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) {
      return;
    }

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        if (_isPlaying) {
          _resumeAfterFocusLoss = true;
          unawaited(_player.pause());
          _isPlaying = false;
        } else {
          _resumeAfterFocusLoss = false;
        }
        break;
      case AppLifecycleState.resumed:
        if (_resumeAfterFocusLoss) {
          unawaited(_player.resume());
          _isPlaying = true;
        }
        break;
      case AppLifecycleState.hidden:
        if (_isPlaying) {
          _resumeAfterFocusLoss = true;
          unawaited(_player.pause());
          _isPlaying = false;
        } else {
          _resumeAfterFocusLoss = false;
        }
        break;
      case AppLifecycleState.detached:
        _resumeAfterFocusLoss = false;
        unawaited(dispose());
        break;
    }
  }

  Future<void> dispose() async {
    if (!_isInitialized) {
      return;
    }
    WidgetsBinding.instance.removeObserver(this);
    await _player.stop();
    await _player.dispose();
    _isInitialized = false;
    _isPlaying = false;
    _resumeAfterFocusLoss = false;
  }
}
