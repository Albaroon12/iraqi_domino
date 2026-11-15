import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  // Required before using platform services (like orientation lock).
  WidgetsFlutterBinding.ensureInitialized();

  // The game is portrait-only.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // ProviderScope stores the state of all Riverpod providers.
  // It must wrap the whole app.
  runApp(const ProviderScope(child: IraqiDominoApp()));
}