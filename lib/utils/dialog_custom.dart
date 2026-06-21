import 'package:flutter/material.dart';

import 'button_custom.dart';
import 'colors.dart';

class CustomDialog {
  static void loading(BuildContext context) {
    showModalBottomSheet(
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colortextwhite,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "Sedang diproses...",
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  static void messageResponse(BuildContext context, String text) {
    showModalBottomSheet(
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colortextwhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF8B5CF6), size: 24),
                    SizedBox(width: 12),
                    Text(
                      "Informasi",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  text,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                ButtonPrimary(
                  onTap: () => Navigator.pop(context),
                  name: "OK",
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void messageDevelopment(BuildContext context) {
    showModalBottomSheet(
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colortextwhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.developer_mode, color: Colors.orange, size: 24),
                    SizedBox(width: 12),
                    Text(
                      "Pengembangan",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "API KEY GOOGLE SERVICE NOT MATCH",
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                ButtonPrimary(
                  onTap: () => Navigator.pop(context),
                  name: "OK",
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Method untuk menutup loading dialog
  static void closeLoading(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}