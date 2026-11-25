import 'dart:io';

import 'package:iraqi_domino/server/domino_online_server.dart';

/// Standalone Pure-Dart CLI entrypoint for the Iraqi Domino Online Server.
///
/// Run locally during development:
///   `dart run bin/server.dart`
/// Compile to a native production binary:
///   `dart compile exe bin/server.dart -o domino_server`
Future<void> main(List<String> args) async {
  var port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  var storagePath =
      Platform.environment['DOMINO_DB_PATH'] ?? 'server_accounts.json';

  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--port') {
      port = int.tryParse(args[i + 1]) ?? port;
    } else if (args[i] == '--storage') {
      storagePath = args[i + 1];
    }
  }

  final server = DominoOnlineServer(storageFilePath: storagePath);
  final boundPort = await server.start(bindPort: port);
  stdout.writeln(
    'Iraqi Domino Online Server listening on http://0.0.0.0:$boundPort (WS /ws)',
  );
}
