// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:bech32/bech32.dart' as bech32;
// import 'package:crypto/crypto.dart' as crypto;
// import 'package:hex/hex.dart';

import 'package:dart_nostr/dart_nostr.dart';

// void main() {
//   // final pubKey =
//   //     "8626bbbaf0cdc52e5e76e8a7e27ee6602bdbf5d0cae9f1448c854493945853f6";

//   // print(pubKey);

//   // final npub = Nostr.instance.keysService.encodePublicKeyToNpub(pubKey);
//   // print(npub);

//   // final key = Nostr.instance.keysService.decodeNpubKeyToPublicKey(npub);
//   // print(key);

// //!
//   // final hex = hexToBytes(
//   //   textToHex("https//example.com" + "/.well-known/lnurlp/" + "anas"),
//   // );

//   // print(hex);

//   // final encoded =
//   //     Nostr.instance.utilsService.encodeBech32(HEX.encode(hex), "lnurl");
//   // print(encoded);

// //!
//   // List<String> list = ["banana", "apple", "orange", "watermelon"];

//   // String encodedJson = jsonEncode(list);
//   // print(encodedJson);

//   final data = "hello";
//   final hash = crypto.sha256.convert(utf8.encode(data)).toString();

//   print(hash);

//   // print(hash);

//   // final pair = Nostr.instance.keysService.generateKeyPair();
//   // print(pair.private);
//   // print(pair.public);
// }

// List<int> hexToBytes(String a) {
//   final length = a.length ~/ 2;
//   return List.generate(length,
//       (index) => int.parse(a.substring(2 * index, 2 * index + 2), radix: 16));
// }

// textToHex(String text) {
//   final bytes = utf8.encode(text);
//   final hex = bytesToHex(bytes);

//   return hex;
// }

// bytesToHex(List<int> bytes) {
//   final hexString =
//       bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');

//   return '$hexString';
// }

Future<void> main() async {
  final instance = Nostr()..disableLogs();

  await instance.relaysService.init(
    relaysUrl: ['wss://relay.damus.io'],
  );

  final sub = instance.relaysService.startEventsSubscription(
    request: NostrRequest(
      filters: [
        NostrFilter(kinds: [1], limit: 50),
      ],
    ),
  );

  sub.stream.listen((event) {
    print("\n");
    print(event.content);
  });
}
