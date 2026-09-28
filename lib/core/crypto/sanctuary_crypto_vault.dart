import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptedMessagePacket {
  final String ciphertextBase64;
  final String nonceBase64;
  final String macBase64;

  EncryptedMessagePacket({
    required this.ciphertextBase64,
    required this.nonceBase64,
    required this.macBase64,
  });

  Map<String, String> toJson() => {
    'ciphertext': ciphertextBase64,
    'nonce': nonceBase64,
    'mac': macBase64,
  };

  factory EncryptedMessagePacket.fromJson(Map<String, dynamic> json) {
    return EncryptedMessagePacket(
      ciphertextBase64: json['ciphertext'] as String? ?? '',
      nonceBase64: json['nonce'] as String? ?? '',
      macBase64: json['mac'] as String? ?? '',
    );
  }
}

class SanctuaryCryptoVault {
  static final SanctuaryCryptoVault instance = SanctuaryCryptoVault._internal();
  SanctuaryCryptoVault._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final X25519 _x25519 = X25519();
  final Chacha20 _cipher = Chacha20.poly1305Aead();

  static const String _privKeyStorageKey = 'urheart_x25519_private_seed';
  static const String _pubKeyStorageKey = 'urheart_x25519_public_bytes';

  /// Generates or loads the persistent device X25519 keypair.
  Future<SimpleKeyPair> getOrCreateLocalKeyPair() async {
    final existingPrivate = await _secureStorage.read(key: _privKeyStorageKey);

    if (existingPrivate != null && existingPrivate.isNotEmpty) {
      final privateBytes = base64Decode(existingPrivate);
      return await _x25519.newKeyPairFromSeed(privateBytes);
    }

    final newKeyPair = await _x25519.newKeyPair();
    final privateKey = await newKeyPair.extractPrivateKeyBytes();
    final publicKey = await newKeyPair.extractPublicKey();

    await _secureStorage.write(key: _privKeyStorageKey, value: base64Encode(privateKey));
    await _secureStorage.write(key: _pubKeyStorageKey, value: base64Encode(publicKey.bytes));

    return newKeyPair;
  }

  /// Derives shared 256-bit secret with peer's public key using Diffie-Hellman.
  Future<SecretKey> deriveSharedSecret(List<int> peerPublicKeyBytes) async {
    final localKeyPair = await getOrCreateLocalKeyPair();
    final peerPublicKey = SimplePublicKey(peerPublicKeyBytes, type: KeyPairType.x25519);

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: peerPublicKey,
    );

    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return await hkdf.deriveKey(
      secretKey: sharedSecret,
      info: utf8.encode('UR-Heart-E2EE-v1'),
    );
  }

  /// Encrypts plaintext dialogue using ChaCha20-Poly1305 AEAD.
  Future<EncryptedMessagePacket> encryptDialogueText({
    required String plainText,
    required List<int> peerPublicKeyBytes,
  }) async {
    final secretKey = await deriveSharedSecret(peerPublicKeyBytes);
    final clearBytes = utf8.encode(plainText);

    final secretBox = await _cipher.encrypt(
      clearBytes,
      secretKey: secretKey,
    );

    return EncryptedMessagePacket(
      ciphertextBase64: base64Encode(secretBox.cipherText),
      nonceBase64: base64Encode(secretBox.nonce),
      macBase64: base64Encode(secretBox.mac.bytes),
    );
  }

  /// Decrypts dialogue packet using derived shared secret.
  Future<String?> decryptDialoguePacket({
    required EncryptedMessagePacket packet,
    required List<int> peerPublicKeyBytes,
  }) async {
    try {
      final secretKey = await deriveSharedSecret(peerPublicKeyBytes);

      final secretBox = SecretBox(
        base64Decode(packet.ciphertextBase64),
        nonce: base64Decode(packet.nonceBase64),
        mac: Mac(base64Decode(packet.macBase64)),
      );

      final decryptedBytes = await _cipher.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return utf8.decode(decryptedBytes);
    } catch (_) {
      return null;
    }
  }

  /// Exports current public key in Base64 for database registration.
  Future<String> exportPublicKeyBase64() async {
    final keyPair = await getOrCreateLocalKeyPair();
    final pubKey = await keyPair.extractPublicKey();
    return base64Encode(pubKey.bytes);
  }
}
