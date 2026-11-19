import 'package:bip32_bip44/dart_bip32_bip44.dart' as bip32_bip44;
import 'package:bip39/bip39.dart' as bip39;

/// {@template nip06}
/// NIP-06 key derivation from BIP-39 mnemonics using the Nostr derivation
/// path `m/44'/1237'/0'/0/0`.
/// {@endtemplate}
class NostrNip06 {
  /// {@macro nip06}
  const NostrNip06();

  /// Wether the given [text] is a valid BIP-39 mnemonic.
  bool isMnemonicValid(String text) {
    return bip39.validateMnemonic(text);
  }

  /// Derives a private key from a [mnemonic] directly.
  String privateKeyFromMnemonic(String mnemonic) {
    final seed = bip39.mnemonicToSeedHex(mnemonic);
    final chain = bip32_bip44.Chain.seed(seed);

    final key =
        chain.forPath("m/44'/1237'/0'/0") as bip32_bip44.ExtendedPrivateKey;

    final childKey = bip32_bip44.deriveExtendedPrivateChildKey(key, 0);

    var hexChildKey = '';

    if (childKey.key != null) {
      // The BIP-32 key bytes are a big-endian 32-byte integer; converting to a
      // hex string via toRadixString drops leading zero bytes, producing keys
      // shorter than 64 chars (invalid). Left-pad to exactly 64 chars.
      hexChildKey = childKey.key!.toRadixString(16).padLeft(64, '0');
    }

    return hexChildKey;
  }
}
