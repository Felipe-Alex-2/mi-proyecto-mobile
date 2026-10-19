import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores only a preference and account ID, never a password or fingerprint.
class BiometricService {
  final LocalAuthentication device;
  final FlutterSecureStorage secure;
  BiometricService({LocalAuthentication? device, FlutterSecureStorage? secure})
    : device = device ?? LocalAuthentication(),
      secure = secure ?? const FlutterSecureStorage();
  Future<bool> enabledFor(String id) async =>
      await secure.read(key: 'biometric_owner') == id;
  Future<bool> available() async {
    try {
      return await device.isDeviceSupported() &&
          (await device.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verify() async {
    try {
      return await device.authenticate(
        localizedReason: 'Desbloquea VESTA con la biometría de tu dispositivo',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> enable(String id) async {
    if (!await available() || !await verify()) return false;
    await secure.write(key: 'biometric_owner', value: id);
    return true;
  }

  Future<void> disable() => secure.delete(key: 'biometric_owner');
}
