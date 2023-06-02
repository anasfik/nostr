abstract class NostrUtilsBase {
  bool isValidNip05Identifier(String identifier);

  String hexEncodeString(String input);

  String random64HexChars();

  Future<bool> verifyNip05({
    required String internetIdentifier,
    required String pubKey,
  });

  Future<String> pubKeyFromIdentifierNip05({
    required String internetIdentifier,
  });

  Map<String, dynamic> decodeNprofileToMap(String bech32);

  Map<String, dynamic> decodeNeventToMap(String bech32);

  String encodeNProfile({
    required String pubkey,
    List<String> userRelays = const [],
  });

  String encodeNevent({
    required String eventId,
    required String pubkey,
    List<String> userRelays = const [],
  });

  String encodeBech32(String hex, String hrp);

  List<String> decodeBech32(String bech32String);

  int countDifficultyOfHex(String hexString);
}
