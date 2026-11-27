// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/security/pin_attempt_guard.dart';
import 'package:fluffychat/widgets/lock_screen.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class AppLockWidget extends StatefulWidget {
  const AppLockWidget({
    required this.child,
    required this.pincode,
    required this.useBiometrics,
    required this.isLoggedIn,
    super.key,
  });

  final bool isLoggedIn, useBiometrics;
  final String? pincode;
  final Widget child;

  @override
  State<AppLockWidget> createState() => AppLock();
}

class AppLock extends State<AppLockWidget> with WidgetsBindingObserver {
  static const _attemptKey = 'matrixchat.pin_attempt_state';
  static const _storage = FlutterSecureStorage();
  final _pinAttempts = PinAttemptGuard(
    read: () => _storage.read(key: _attemptKey),
    write: (value) => _storage.write(key: _attemptKey, value: value),
  );

  String? _pincode;
  bool _isLocked = false;
  bool _useBiometrics = false;
  bool _triedAutoBiometrics = false;
  bool _biometricInProgress = false;
  bool _paused = false;
  bool get isActive =>
      _pincode != null &&
      int.tryParse(_pincode!) != null &&
      _pincode!.length >= 4 &&
      !_paused;
  bool get useBiometrics => _useBiometrics;

  @override
  void initState() {
    _useBiometrics = widget.useBiometrics;
    _pincode = widget.pincode;
    _isLocked = isActive;
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (isActive && useBiometrics) unlockWithBiometrics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (isActive &&
        (state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused) &&
        !_isLocked) {
      showLockScreen();
    }
    if (_isLocked &&
        state == AppLifecycleState.resumed &&
        useBiometrics &&
        !_triedAutoBiometrics) {
      unlockWithBiometrics();
    }
  }

  bool get isLocked => _isLocked;
  bool get hasPincode => _pincode != null;

  int get pinRetryAfterSeconds => _pinAttempts.retryAfterSeconds;

  Future<bool> verifyCurrentPin(String pin) =>
      _pinAttempts.verify(() => _pincode != null && pin == _pincode);

  Future<void> changeUseBiometrics(bool useBiometrics) async {
    await const FlutterSecureStorage().write(
      key: 'chat.fluffy.use_biometrics',
      value: useBiometrics.toString(),
    );
    _useBiometrics = useBiometrics;
    return;
  }

  Future<void> changePincode(String? pincode) async {
    await const FlutterSecureStorage().write(
      key: 'chat.fluffy.app_lock',
      value: pincode,
    );
    if (!mounted) return;
    setState(() {
      _pincode = pincode;
      if (pincode == null) _isLocked = false;
    });
  }

  Future<bool> unlockWithBiometrics() async {
    if (_biometricInProgress || !useBiometrics) return false;
    _biometricInProgress = true;
    _triedAutoBiometrics = true;
    final localAuth = LocalAuthentication();
    bool unlocked;
    try {
      unlocked = await localAuth.authenticate(
        localizedReason: 'Please authenticate to unlock the app.',
        persistAcrossBackgrounding: true,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    } finally {
      _biometricInProgress = false;
    }
    if (!mounted) return false;
    if (unlocked) {
      try {
        await _pinAttempts.resetAfterBiometric();
      } catch (_) {
        return false;
      }
      if (!mounted) return false;
      setState(() {
        _isLocked = false;
        _triedAutoBiometrics = false;
      });
    }
    return unlocked;
  }

  Future<bool> unlock(String pincode) async {
    final isCorrect = await verifyCurrentPin(pincode);
    if (!mounted) return false;
    if (isCorrect) {
      setState(() {
        _isLocked = false;
      });
    }
    return isCorrect;
  }

  void showLockScreen() {
    MxcImage.clearAllCaches();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    setState(() {
      _isLocked = true;
    });
  }

  Future<T> pauseWhile<T>(Future<T> future) async {
    _paused = true;
    try {
      return await future;
    } finally {
      _paused = false;
    }
  }

  static AppLock of(BuildContext context) =>
      Provider.of<AppLock>(context, listen: false);

  @override
  Widget build(BuildContext context) => Provider<AppLock>(
    create: (_) => this,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: isLocked,
          child: Visibility(
            visible: !isLocked,
            maintainState: true,
            child: widget.child,
          ),
        ),
        if (isLocked) const LockScreen(),
      ],
    ),
  );
}
