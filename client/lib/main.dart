import 'package:flutter/material.dart';

import 'app.dart';
import 'services/local_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.create();
  runApp(WasteApp(store: store));
}

class WasteApp extends StatelessWidget {
  const WasteApp({super.key, required this.store});

  final LocalStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'WASTE',
        debugShowCheckedModeBanner: false,
        theme: WasteTheme.dark(),
        home: WasteShell(store: store),
      );
}
