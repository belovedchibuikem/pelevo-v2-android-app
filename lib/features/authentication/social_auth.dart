import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SocialAuthTokens {
  const SocialAuthTokens({
    required this.provider,
    required this.token,
    this.nonce,
  });

  final String provider;
  final String token;
  final String? nonce;
}

/// Google is the Android sign-in option. Apple is the iOS sign-in option.
bool get showsGoogleSignIn =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool get showsAppleSignIn =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

class SocialAuthService {
  static bool _googleReady = false;

  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '34338451494-69iirpso5jj0lj72li7ucv21r9gbpddd.apps.googleusercontent.com',
  );

  static Future<void> _ensureGoogle() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
    _googleReady = true;
  }

  static Future<SocialAuthTokens> google() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      throw const ApiFailure(
        code: 'UNSUPPORTED',
        message: 'Google Sign-In requires Android or iOS.',
      );
    }
    await _ensureGoogle();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const ApiFailure(
        code: 'UNSUPPORTED',
        message: 'Google Sign-In authenticate is not supported here.',
      );
    }
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: const ['email', 'profile'],
    );
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw const ApiFailure(
        code: 'SOCIAL_TOKEN_MISSING',
        message:
            'Google did not return an ID token. Build the app with GOOGLE_SERVER_CLIENT_ID so the token can be verified.',
      );
    }
    return SocialAuthTokens(provider: 'google', token: token);
  }

  static Future<SocialAuthTokens> apple() async {
    if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) {
      throw const ApiFailure(
        code: 'UNSUPPORTED',
        message: 'Sign in with Apple requires iOS or macOS.',
      );
    }
    final available = await SignInWithApple.isAvailable();
    if (!available) {
      throw const ApiFailure(
        code: 'UNSUPPORTED',
        message: 'Sign in with Apple is not available on this device.',
      );
    }
    final nonce = _randomNonce();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: sha256.convert(utf8.encode(nonce)).toString(),
    );
    final token = credential.identityToken;
    if (token == null || token.isEmpty) {
      throw const ApiFailure(
        code: 'SOCIAL_TOKEN_MISSING',
        message: 'Apple did not return a verifiable identity token.',
      );
    }
    return SocialAuthTokens(provider: 'apple', token: token, nonce: nonce);
  }
}

String _randomNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}
