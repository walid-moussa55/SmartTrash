import 'package:flutter/material.dart';

// --- Visual Constants (NaqiAI System) ---
const _kBg = Color(0xFFF5F3EE);
const _kSurface = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE2DDD5);
const _kPrimary = Color(0xFF2A4A30);
const _kTextGray = Color(0xFF7A8A7C);
const _kMid = Color(0xFF5C8E60);

class DebugLogger {
  static final List<String> _debugMessages = []; // Persistent list

  static void addDebugMessage(String message) {
    _debugMessages.add("[${DateTime.now().toString().split(' ')[1].substring(0, 8)}] $message");
    debugPrint(message); // Print to console for immediate feedback
    if (_debugMessages.length > 200) {
      _debugMessages.removeAt(0); // Keep log size manageable
    }
  }

  static void showDebugDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 800,
            constraints: const BoxConstraints(maxHeight: 600),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: _kBorder, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const Icon(Icons.terminal_rounded, color: _kPrimary, size: 24),
                      const SizedBox(width: 14),
                      const Text(
                        "DIAGNOSTIC SYSTÈME",
                        style: TextStyle(color: _kPrimary, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: _kTextGray),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(color: _kBorder, height: 1),
                // Body
                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _debugMessages.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final msg = _debugMessages[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _kSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kBorder.withOpacity(0.5)),
                        ),
                        child: Text(
                          msg,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: _kPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text("TERMINER", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}