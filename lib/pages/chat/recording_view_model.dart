// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'events/audio_player.dart';

class RecordingViewModel extends StatefulWidget {
  final Widget Function(BuildContext, RecordingViewModelState) builder;

  const RecordingViewModel({required this.builder, super.key});

  @override
  RecordingViewModelState createState() => RecordingViewModelState();
}

class RecordingViewModelState extends State<RecordingViewModel> {
  Timer? _recorderSubscription;
  Duration duration = Duration.zero;

  bool get isRecording => _audioRecorder != null;

  AudioRecorder? _audioRecorder;
  final List<double> amplitudeTimeline = [];

  String? fileName;
  String? _ownedRecordingPath;
  bool _sending = false;

  bool isPaused = false;

  Future<void> startRecording(Room room) async {
    if (_sending || isRecording) return;
    room.client.getConfig(); // Preload server file configuration.
    if (PlatformInfos.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      if (!mounted) return;
      if (info.version.sdkInt < 19) {
        showOkAlertDialog(
          context: context,
          title: L10n.of(context).unsupportedAndroidVersion,
          message: L10n.of(context).unsupportedAndroidVersionLong,
          okLabel: L10n.of(context).close,
        );
        return;
      }
    }
    if (await AudioRecorder().hasPermission() == false) return;

    final audioRecorder = _audioRecorder ??= AudioRecorder();
    setState(() {});

    try {
      final codec =
          await audioRecorder.isEncoderSupported(AudioEncoder.opus) &&
              !(PlatformInfos.isMacOS || PlatformInfos.isIOS)
          ? AudioEncoder.opus
          : AudioEncoder.aacLc;
      fileName =
          'voice_message_${DateTime.now().millisecondsSinceEpoch}.${codec.fileExtension}';
      String? path;
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        path = path_lib.join(tempDir.path, fileName);
        _ownedRecordingPath = path;
      }

      final result = await audioRecorder.hasPermission();
      if (result != true) {
        if (!mounted) return;
        showOkAlertDialog(
          context: context,
          title: L10n.of(context).oopsSomethingWentWrong,
          message: L10n.of(context).noPermission,
        );
        return;
      }
      await WakelockPlus.enable();

      await audioRecorder.start(
        RecordConfig(
          bitRate: AppSettings.audioRecordingBitRate.value,
          sampleRate: AppSettings.audioRecordingSamplingRate.value,
          numChannels: AppSettings.audioRecordingNumChannels.value,
          autoGain: AppSettings.audioRecordingAutoGain.value,
          echoCancel: AppSettings.audioRecordingEchoCancel.value,
          noiseSuppress: AppSettings.audioRecordingNoiseSuppress.value,
          encoder: codec,
        ),
        path: path ?? '',
      );
      if (!mounted) return;
      setState(() => duration = Duration.zero);
      _subscribe();
    } catch (_) {
      Logs().w('Unable to start voice message recording.');
      if (!mounted) return;
      showOkAlertDialog(
        context: context,
        title: L10n.of(context).oopsSomethingWentWrong,
        message: L10n.of(context).oopsSomethingWentWrong,
      );
      setState(_reset);
    }
  }

  @override
  void dispose() {
    _reset();
    super.dispose();
  }

  void _subscribe() {
    _recorderSubscription?.cancel();
    _recorderSubscription = Timer.periodic(const Duration(milliseconds: 100), (
      _,
    ) async {
      final recorder = _audioRecorder;
      if (recorder == null || !mounted) return;
      final amplitude = await recorder.getAmplitude();
      if (!mounted || !identical(recorder, _audioRecorder)) return;
      var value = 100 + amplitude.current * 2;
      value = value < 1 ? 1 : value;
      amplitudeTimeline.add(value);
      setState(() {
        duration += const Duration(milliseconds: 100);
      });
    });
  }

  void _reset() {
    WakelockPlus.disable();
    _recorderSubscription?.cancel();
    final recorder = _audioRecorder;
    final ownedPath = _ownedRecordingPath;
    _audioRecorder = null;
    _ownedRecordingPath = null;
    if (recorder != null) {
      unawaited(_cancelAndDispose(recorder, ownedPath));
    }

    fileName = null;
    duration = Duration.zero;
    amplitudeTimeline.clear();
    isPaused = false;
  }

  Future<void> _deleteOwnedRecording(String? ownedPath) async {
    if (kIsWeb || ownedPath == null) return;
    try {
      final file = File(ownedPath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      Logs().w('Temporary voice file cleanup failed.');
    }
  }

  Future<void> _cancelAndDispose(
    AudioRecorder recorder,
    String? ownedPath,
  ) async {
    try {
      await recorder.cancel();
    } catch (_) {
      Logs().w('Voice recording cancellation failed.');
    } finally {
      try {
        await recorder.dispose();
      } catch (_) {
        Logs().w('Voice recorder disposal failed.');
      } finally {
        await _deleteOwnedRecording(ownedPath);
      }
    }
  }

  void cancel() {
    if (_sending) return;
    setState(_reset);
  }

  void pause() {
    _audioRecorder?.pause();
    _recorderSubscription?.cancel();
    setState(() {
      isPaused = true;
    });
  }

  void resume() {
    _audioRecorder?.resume();
    _subscribe();
    setState(() {
      isPaused = false;
    });
  }

  Future<void> stopAndSend(
    Future<void> Function(
      String path,
      int duration,
      List<int> waveform,
      String fileName,
    )
    onSend,
  ) async {
    if (_sending || _audioRecorder == null) return;
    _sending = true;
    _recorderSubscription?.cancel();
    final recorder = _audioRecorder!;
    final ownedPath = _ownedRecordingPath;
    _audioRecorder = null;
    _ownedRecordingPath = null;
    try {
      final path = await recorder.stop();
      if (path == null) throw StateError('Recording failed.');
      const waveCount = AudioPlayerWidget.wavesCount;
      final step = amplitudeTimeline.length < waveCount
          ? 1
          : (amplitudeTimeline.length / waveCount).round();
      final waveform = <int>[];
      for (var i = 0; i < amplitudeTimeline.length; i += step) {
        waveform.add((amplitudeTimeline[i] / 100 * 1024).round());
      }
      final name = fileName;
      if (name == null || !mounted) return;
      await onSend(path, duration.inMilliseconds, waveform, name);
    } finally {
      try {
        await recorder.dispose();
      } finally {
        await _deleteOwnedRecording(ownedPath);
        _sending = false;
        if (mounted) {
          setState(_reset);
        } else {
          WakelockPlus.disable();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, this);
}

extension on AudioEncoder {
  String get fileExtension {
    switch (this) {
      case AudioEncoder.aacLc:
      case AudioEncoder.aacEld:
      case AudioEncoder.aacHe:
        return 'm4a';
      case AudioEncoder.opus:
        return 'ogg';
      case AudioEncoder.wav:
        return 'wav';
      case AudioEncoder.amrNb:
      case AudioEncoder.amrWb:
      case AudioEncoder.flac:
      case AudioEncoder.pcm16bits:
        throw UnsupportedError('Not yet used');
    }
  }
}
