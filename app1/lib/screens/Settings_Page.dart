import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey,
        elevation: 0,
      ), // AppBar
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary,
          borderRadius: BorderRadius.circular(12),
        ), // BoxDecoration
        margin: const EdgeInsets.all(25),
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // dark mode
            Text(
              "Dark Mode",
              style: TextStyle(
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
            // switch toggle
            // CupertinoSwitch(
            //   value: Provider.of<ThemeProvider>(
            //     context,
            //     listen: false,
            //   ).isDarkMode,
            //   onChanged: (value) => Provider.of<ThemeProvider>(
            //     context,
            //     listen: false,
            //   ).toggleTheme(),
            // ), // CupertinoSwitch
          ],
        ), // Row
      ), // Container
    ); // Scaffold
  }
}
