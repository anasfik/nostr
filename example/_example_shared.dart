import 'package:dart_nostr/dart_nostr.dart';

const exampleRelays = <String>[
  'wss://relay.damus.io',
  'wss://nos.lol',
  
];

Nostr exampleNostr({bool enableLogs = false}) {
  final nostr = Nostr.enterprise(
    clientOptions: NostrClientOptions(
      connectionTimeout: const Duration(seconds: 8),
      requestTimeout: const Duration(seconds: 12),
      retryPolicy: NostrRetryPolicy.exponential(
        maxAttempts: 3,
        initialDelayMs: 150,
        maxDelayMs: 1500,
      ),

    ),
    
  );

  if (enableLogs) {
    nostr.enableLogs();
  } else {
    nostr.disableLogs();
  }

  return nostr;
}

Future<Nostr> connectedExampleNostr({
  List<String> relays = exampleRelays,
  bool enableLogs = false,
}) async {
  final nostr = exampleNostr(enableLogs: enableLogs);
  final result = await nostr.connect(relays);

  if (result.isFailure) {
    throw NostrException(result.failureOrNull!);
  }

  return nostr;
}

void printResult<T>(String label, NostrResult<T> result) {
  result.fold(
    (value) => print('$label success: $value'),
    (failure) => print('$label failure: $failure'),
  );
}

String divider([String title = '']) {
  if (title.isEmpty) {
    return '----------------------------------------';
  }

  return '------------ $title ------------';
}
