import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/constants/app_colors.dart';

class BiometricSecurityService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Prompts device fingerprint / face unlock with fallback to PIN
  static Future<bool> authenticate({String reason = 'Unlock note with fingerprint'}) async {
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
    } on PlatformException catch (_) {
      // Fallback to PIN if platform biometrics encounter exception
    } catch (_) {}

    return false;
  }

  /// Displays clean AMOLED PIN entry dialog
  static Future<bool> promptPin(BuildContext context, {String correctPin = '1234', String title = 'Enter PIN'}) async {
    String enteredPin = '';
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.amoledSurfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: AppColors.amoledBorder, width: 1.2),
              ),
              title: Center(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  // PIN Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final isFilled = i < enteredPin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled ? AppColors.samsungOrange : Colors.transparent,
                          border: Border.all(
                            color: isFilled ? AppColors.samsungOrange : Colors.white38,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  // Number Keypad
                  SizedBox(
                    width: 240,
                    child: Column(
                      children: [
                        _buildPinRow(['1', '2', '3'], setState, (val) => _handleDigit(context, val, correctPin, enteredPin, setState)),
                        const SizedBox(height: 12),
                        _buildPinRow(['4', '5', '6'], setState, (val) => _handleDigit(context, val, correctPin, enteredPin, setState)),
                        const SizedBox(height: 12),
                        _buildPinRow(['7', '8', '9'], setState, (val) => _handleDigit(context, val, correctPin, enteredPin, setState)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.fingerprint, color: AppColors.samsungOrange, size: 28),
                              onPressed: () async {
                                final auth = await authenticate();
                                if (auth && context.mounted) {
                                  Navigator.of(context).pop(true);
                                }
                              },
                            ),
                            _buildPinBtn('0', () => _handleDigit(context, '0', correctPin, enteredPin, setState)),
                            IconButton(
                              icon: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 22),
                              onPressed: enteredPin.isNotEmpty
                                  ? () => setState(() => enteredPin = enteredPin.substring(0, enteredPin.length - 1))
                                  : null,
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
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? false;
  }

  static void _handleDigit(
    BuildContext context,
    String digit,
    String correctPin,
    String current,
    StateSetter setState,
  ) {
    if (current.length < 4) {
      final updated = current + digit;
      setState(() {});
      if (updated.length == 4) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (updated == correctPin) {
            Navigator.of(context).pop(true);
          } else {
            // Shake / error feedback
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Incorrect PIN. Try again.'),
                duration: Duration(seconds: 1),
                backgroundColor: AppColors.accentRose,
              ),
            );
            Navigator.of(context).pop(false);
          }
        });
      }
    }
  }

  static Widget _buildPinRow(List<String> digits, StateSetter setState, Function(String) onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildPinBtn(d, () => onTap(d))).toList(),
    );
  }

  static Widget _buildPinBtn(String digit, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.amoledSurface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.amoledBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
