// import 'package:dart_bip32_bip44/dart_bip32_bip44.dart' as bip32_bip44;
// import 'package:bip39/bip39.dart' as bip39;
// 
// // Class to handle Nip-06
// class Nip6 {
//   static Future<void> init() async {}
// 
//   static bool isMnemonicValid(String mnemonic) {
//     return bip39.validateMnemonic(mnemonic);
//   }
// 
//   static String getPrivateKeyFromMnemonic(String mnemonic) {
//     String seed = bip39.mnemonicToSeedHex(mnemonic);
//     bip32_bip44.Chain chain = bip32_bip44.Chain.seed(seed);
// 
//     bip32_bip44.ExtendedPrivateKey key =
//         chain.forPath("m/44'/1237'/0'/0") as bip32_bip44.ExtendedPrivateKey;
// 
//     // Get the first child key.
//     bip32_bip44.ExtendedPrivateKey? childKey =
//         bip32_bip44.deriveExtendedPrivateChildKey(key, 0);
//     String hexChildKey = "";
// 
//     // Per the library docs, the actual key can be returned as BigInt with key.key
//     if (childKey.key != null) {
//       // Convert to hex.
//       hexChildKey = childKey.key!.toRadixString(16);
//     }
//     return hexChildKey;
//   }
// } //  END OF CLASS
// 
