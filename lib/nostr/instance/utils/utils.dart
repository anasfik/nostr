import 'base/base.dart';

/// {@template nostr_utils}
/// This class is responsible for handling some of the helper utils of the library.
/// {@endtemplate}
class NostrUtils implements NostrUtilsBase {
  @override
  bool isValidNip05Identifier(String identifier) {
    final emailRegEx =
        RegExp(r'^[a-zA-Z0-9_\-\.]+@[a-zA-Z0-9_\-\.]+\.[a-zA-Z]+$');

    return emailRegEx.hasMatch(identifier);
  }
}
