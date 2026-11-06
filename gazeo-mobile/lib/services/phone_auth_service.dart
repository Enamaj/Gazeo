import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class PhoneAuthService {
  static final PhoneAuthService _instance = PhoneAuthService._internal();
  factory PhoneAuthService() => _instance;
  PhoneAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId;
  int? _resendToken;

  String? get verificationId => _verificationId;

  /// Envoie un code SMS OTP de 6 chiffres via Firebase
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
    void Function(PhoneAuthCredential credential)? onAutoVerified,
  }) async {
    try {
      // Normalisation du numéro pour le Cameroun (+237)
      String formattedPhone = phoneNumber.replaceAll(RegExp(r'[\s\-]'), '');
      if (!formattedPhone.startsWith('+')) {
        if (formattedPhone.startsWith('237')) {
          formattedPhone = '+$formattedPhone';
        } else {
          formattedPhone = '+237$formattedPhone';
        }
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('[Firebase PhoneAuth] Auto-vérification réussie !');
          if (onAutoVerified != null) {
            onAutoVerified(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('[Firebase PhoneAuth] Échec envoi : ${e.code} - ${e.message}');
          String errorMsg = 'Erreur lors de l\'envoi du SMS.';
          if (e.code == 'invalid-phone-number') {
            errorMsg = 'Numéro de téléphone invalide.';
          } else if (e.code == 'quota-exceeded') {
            errorMsg = 'Quota de SMS dépassé. Utilisez le code test.';
          } else if (e.message != null) {
            errorMsg = e.message!;
          }
          onError(errorMsg);
        },
        codeSent: (String verId, int? resendToken) {
          debugPrint('[Firebase PhoneAuth] Code envoyé avec succès : $verId');
          _verificationId = verId;
          _resendToken = resendToken;
          onCodeSent(verId);
        },
        codeAutoRetrievalTimeout: (String verId) {
          _verificationId = verId;
        },
      );
    } catch (e) {
      onError('Erreur : $e');
    }
  }

  /// Valide le code OTP saisi par l'utilisateur
  Future<UserCredential?> verifyOtp({
    required String smsCode,
    String? customVerificationId,
  }) async {
    final vId = customVerificationId ?? _verificationId;
    if (vId == null || vId.isEmpty) {
      throw Exception('Aucune session de vérification active.');
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: vId,
      smsCode: smsCode,
    );

    return await _auth.signInWithCredential(credential);
  }
}
