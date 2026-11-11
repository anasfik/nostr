import 'dart:io';

import 'package:test/test.dart';

/// Parses only top-level entries from the real pub archive tree.
///
/// Nested entries are prefixed with `│` or spaces, so anchoring at column 0
/// prevents a nested basename from being mistaken for a top-level path.
Set<String> parseTopLevelArchiveEntries(String output) {
  final matches = RegExp(
    r'^[├└]── (.+?)(?: \([^)]*\))?[ \t]*\r?$',
    multiLine: true,
  ).allMatches(output);

  return {
    for (final match in matches)
      match.group(1)!.trim().replaceFirst(RegExp(r'/+$'), ''),
  };
}

/// Opt-in check against the real pub archive listing:
///   RUN_PACKAGE_ARCHIVE_CHECK=1 dart test test/package_archive_test.dart
///
/// It never publishes; `--dry-run` only builds and lists the archive.
void main() {
  test('top-level archive parser ignores nested basenames', () {
    const output = '''
Publishing example 1.0.0 to https://pub.dev:
├── CHANGELOG.md (12.98 KB)
├── lib
│   ├── dart_nostr.dart (0.5 KB)
│   └── src
│       └── channel.dart (2.1 KB)
├── playground (92.3 MB)
└── pubspec.yaml (544 B)
''';

    expect(
      parseTopLevelArchiveEntries(output),
      {'CHANGELOG.md', 'lib', 'playground', 'pubspec.yaml'},
    );
  });

  test(
    'published archive excludes local-only and generated paths',
    () async {
      if (Platform.environment['RUN_PACKAGE_ARCHIVE_CHECK'] != '1') {
        markTestSkipped(
          'Opt-in: RUN_PACKAGE_ARCHIVE_CHECK=1 dart test '
          'test/package_archive_test.dart',
        );
        return;
      }

      final result = await Process.run(
        Platform.resolvedExecutable,
        ['pub', 'publish', '--dry-run'],
        workingDirectory: Directory.current.path,
      );
      final output = '${result.stdout}\n${result.stderr}';
      expect(result.exitCode, 0, reason: output);

      final listed = parseTopLevelArchiveEntries(output);
      expect(listed, isNotEmpty, reason: 'Could not parse archive listing');
      expect(
        listed,
        containsAll(<String>['lib', 'pubspec.yaml']),
        reason: 'Sanity check: package sources must still ship',
      );

      const forbiddenTopLevel = {
        'playground',
        'ops',
        'technical_docs',
        'build',
        'doc',
        'pubspec.lock',
        'handling',
        'todo.extensionThatDoNotExist',
        '.dart_tool',
        '.packages',
        '.flutter-plugins',
        '.flutter-plugins-dependencies',
        'docs',
        'example',
      };
      for (final entry in listed) {
        expect(
          forbiddenTopLevel.contains(entry),
          isFalse,
          reason: 'Archive includes excluded top-level path: $entry',
        );
        expect(
          entry.startsWith('.env'),
          isFalse,
          reason: 'Archive includes environment file: $entry',
        );
        expect(
          entry.endsWith('.dart.js') ||
              entry.endsWith('.js') ||
              entry.endsWith('.js.map') ||
              entry.endsWith('.js_') ||
              entry.endsWith('.js.deps') ||
              entry.endsWith('.info.json'),
          isFalse,
          reason: 'Archive includes generated JavaScript artifact: $entry',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
