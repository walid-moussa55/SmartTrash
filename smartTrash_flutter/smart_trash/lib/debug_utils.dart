import 'package:flutter/material.dart';

class DebugLogger {
  static final List<String> _debugMessages = []; // Persistent list

  static void addDebugMessage(String message) {
    _debugMessages.add(message);
    print(message); // Print to console for immediate feedback
    if (_debugMessages.length > 100) {
      _debugMessages.removeAt(0); // Keep log size manageable
    }
  }

  static void showDebugDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Debug Messages"),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _debugMessages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_debugMessages[index]),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }
}