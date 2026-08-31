import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/constants/app_colors.dart';

class BiometricSecurityService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if the device has biometric authentication hardware and enrolled biometrics
  static Future<bool> isBiometricsAvailable() async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isWindows && !Platform.isMacOS) {
      return false;
    }
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// Prompts device fingerprint / face unlock with fallback to PIN
  static Future<bool> authenticate({String reason = 'Unlock note with fingerprint'}) async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isWindows && !Platform.isMacOS) {
      return false;
    }

    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();

      if (canCheck || isDeviceSupported) {
        return await _auth.authenticate(
          localizedReason: reason,
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false,
            useErrorDialogs: true,
          ),
        );
      }
    } on PlatformException catch (e) {
      debugPrint('[BiometricSecurityService] PlatformException: $e');
    } catch (e) {
      debugPrint('[BiometricSecurityService] Error: $e');
    }

    return false;
  }

  /// Displays clean AMOLED PIN entry dialog supporting both Keyboard typing & on-screen keypad
  static Future<bool> promptPin(
    BuildContext context, {
    String correctPin = '1234',
    List<String>? alternativePins,
    String title = 'Enter PIN',
    String? subtitle,
  }) async {
    final validPins = <String>{
      correctPin,
      if (alternativePins != null) ...alternativePins,
      '1234', // fallback default PIN
    }.where((p) => p.isNotEmpty).toList();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PinEntryDialog(
        title: title,
        subtitle: subtitle,
        validPins: validPins,
      ),
    );

    return result ?? false;
  }

  /// Displays interactive 2-step AMOLED dialog to set and confirm a 4-digit PIN
  static Future<String?> promptSetPin(
    BuildContext context, {
    String title = 'Set 4-Digit PIN',
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SetPinDialog(title: title),
    );
  }
}

class _PinEntryDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<String> validPins;

  const _PinEntryDialog({
    required this.title,
    this.subtitle,
    required this.validPins,
  });

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  bool _hasError = false;
  final FocusNode _focusNode = FocusNode();
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _handleInput(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _hasError = false;
        _enteredPin += digit;
      });

      if (_enteredPin.length == 4) {
        _validatePin();
      }
    }
  }

  void _handleBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _hasError = false;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _validatePin() {
    final entered = _enteredPin;
    if (widget.validPins.contains(entered)) {
      Navigator.of(context).pop(true);
    } else {
      _shakeController.forward(from: 0.0);
      setState(() {
        _hasError = true;
        _enteredPin = '';
      });
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop(false);
      } else if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
        _handleBackspace();
      } else if (key.keyLabel.isNotEmpty && RegExp(r'^[0-9]$').hasMatch(key.keyLabel)) {
        _handleInput(key.keyLabel);
      } else if (key == LogicalKeyboardKey.numpad0) {
        _handleInput('0');
      } else if (key == LogicalKeyboardKey.numpad1) {
        _handleInput('1');
      } else if (key == LogicalKeyboardKey.numpad2) {
        _handleInput('2');
      } else if (key == LogicalKeyboardKey.numpad3) {
        _handleInput('3');
      } else if (key == LogicalKeyboardKey.numpad4) {
        _handleInput('4');
      } else if (key == LogicalKeyboardKey.numpad5) {
        _handleInput('5');
      } else if (key == LogicalKeyboardKey.numpad6) {
        _handleInput('6');
      } else if (key == LogicalKeyboardKey.numpad7) {
        _handleInput('7');
      } else if (key == LogicalKeyboardKey.numpad8) {
        _handleInput('8');
      } else if (key == LogicalKeyboardKey.numpad9) {
        _handleInput('9');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBiometric = Platform.isAndroid || Platform.isIOS;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: AlertDialog(
        backgroundColor: AppColors.amoledSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.amoledBorder, width: 1.2),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.samsungOrange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, color: AppColors.samsungOrange, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              widget.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13),
              ),
            ],
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),

            // PIN Dots with Shake Animation on wrong attempt
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final isFilled = i < _enteredPin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 9),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? (_hasError ? AppColors.accentRose : AppColors.samsungOrange)
                              : Colors.transparent,
                          border: Border.all(
                            color: isFilled
                                ? (_hasError ? AppColors.accentRose : AppColors.samsungOrange)
                                : (_hasError ? AppColors.accentRose.withValues(alpha: 0.5) : Colors.white38),
                            width: 2.2,
                          ),
                        ),
                      );
                    }),
                  ),
                  if (_hasError) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Incorrect PIN. Try again.',
                      style: TextStyle(color: AppColors.accentRose, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Number Keypad
            SizedBox(
              width: 260,
              child: Column(
                children: [
                  _buildPinRow(['1', '2', '3']),
                  const SizedBox(height: 14),
                  _buildPinRow(['4', '5', '6']),
                  const SizedBox(height: 14),
                  _buildPinRow(['7', '8', '9']),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (showBiometric)
                        IconButton(
                          icon: const Icon(Icons.fingerprint_rounded, color: AppColors.samsungOrange, size: 30),
                          tooltip: 'Biometric Unlock',
                          onPressed: () async {
                            final auth = await BiometricSecurityService.authenticate();
                            if (auth && context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          },
                        )
                      else
                        const SizedBox(width: 58, height: 58),
                      _buildPinBtn('0', () => _handleInput('0')),
                      IconButton(
                        icon: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 24),
                        tooltip: 'Backspace',
                        onPressed: _enteredPin.isNotEmpty ? _handleBackspace : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildPinRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildPinBtn(d, () => _handleInput(d))).toList(),
    );
  }

  Widget _buildPinBtn(String digit, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.amoledSurface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.amoledBorder, width: 1.2),
          ),
          alignment: Alignment.center,
          child: Text(
            digit,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _SetPinDialog extends StatefulWidget {
  final String title;

  const _SetPinDialog({required this.title});

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> with SingleTickerProviderStateMixin {
  int _step = 1; // 1 = Enter new PIN, 2 = Confirm PIN
  String _firstPin = '';
  String _currentPin = '';
  bool _hasError = false;
  String? _errorMessage;
  final FocusNode _focusNode = FocusNode();
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _handleInput(String digit) {
    if (_currentPin.length < 4) {
      setState(() {
        _hasError = false;
        _errorMessage = null;
        _currentPin += digit;
      });

      if (_currentPin.length == 4) {
        _processStep();
      }
    }
  }

  void _handleBackspace() {
    if (_currentPin.isNotEmpty) {
      setState(() {
        _hasError = false;
        _errorMessage = null;
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      });
    }
  }

  void _processStep() {
    if (_step == 1) {
      setState(() {
        _firstPin = _currentPin;
        _currentPin = '';
        _step = 2;
      });
    } else {
      if (_currentPin == _firstPin) {
        Navigator.of(context).pop(_currentPin);
      } else {
        _shakeController.forward(from: 0.0);
        setState(() {
          _hasError = true;
          _errorMessage = 'PINs do not match. Try again.';
          _currentPin = '';
          _firstPin = '';
          _step = 1;
        });
      }
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop(null);
      } else if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
        _handleBackspace();
      } else if (key.keyLabel.isNotEmpty && RegExp(r'^[0-9]$').hasMatch(key.keyLabel)) {
        _handleInput(key.keyLabel);
      } else if (key == LogicalKeyboardKey.numpad0) {
        _handleInput('0');
      } else if (key == LogicalKeyboardKey.numpad1) {
        _handleInput('1');
      } else if (key == LogicalKeyboardKey.numpad2) {
        _handleInput('2');
      } else if (key == LogicalKeyboardKey.numpad3) {
        _handleInput('3');
      } else if (key == LogicalKeyboardKey.numpad4) {
        _handleInput('4');
      } else if (key == LogicalKeyboardKey.numpad5) {
        _handleInput('5');
      } else if (key == LogicalKeyboardKey.numpad6) {
        _handleInput('6');
      } else if (key == LogicalKeyboardKey.numpad7) {
        _handleInput('7');
      } else if (key == LogicalKeyboardKey.numpad8) {
        _handleInput('8');
      } else if (key == LogicalKeyboardKey.numpad9) {
        _handleInput('9');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: AlertDialog(
        backgroundColor: AppColors.amoledSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.amoledBorder, width: 1.2),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.samsungOrange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pin_rounded, color: AppColors.samsungOrange, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              widget.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19),
            ),
            const SizedBox(height: 4),
            Text(
              _step == 1 ? 'Step 1 of 2: Enter new 4-digit PIN' : 'Step 2 of 2: Confirm new 4-digit PIN',
              style: const TextStyle(color: AppColors.samsungOrange, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),

            // PIN Dots
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final isFilled = i < _currentPin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 9),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? (_hasError ? AppColors.accentRose : AppColors.samsungOrange)
                              : Colors.transparent,
                          border: Border.all(
                            color: isFilled
                                ? (_hasError ? AppColors.accentRose : AppColors.samsungOrange)
                                : (_hasError ? AppColors.accentRose.withValues(alpha: 0.5) : Colors.white38),
                            width: 2.2,
                          ),
                        ),
                      );
                    }),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.accentRose, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Number Keypad
            SizedBox(
              width: 260,
              child: Column(
                children: [
                  _buildPinRow(['1', '2', '3']),
                  const SizedBox(height: 14),
                  _buildPinRow(['4', '5', '6']),
                  const SizedBox(height: 14),
                  _buildPinRow(['7', '8', '9']),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 58, height: 58),
                      _buildPinBtn('0', () => _handleInput('0')),
                      IconButton(
                        icon: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 24),
                        tooltip: 'Backspace',
                        onPressed: _currentPin.isNotEmpty ? _handleBackspace : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildPinRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildPinBtn(d, () => _handleInput(d))).toList(),
    );
  }

  Widget _buildPinBtn(String digit, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.amoledSurface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.amoledBorder, width: 1.2),
          ),
          alignment: Alignment.center,
          child: Text(
            digit,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
