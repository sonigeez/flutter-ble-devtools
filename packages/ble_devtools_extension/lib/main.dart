import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'src/ble_devtools_screen.dart';

void main() => runApp(const BleDevToolsExtension());

class BleDevToolsExtension extends StatelessWidget {
  const BleDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) => const DevToolsExtension(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: BleDevToolsScreen(),
        ),
      );
}
