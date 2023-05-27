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
}
