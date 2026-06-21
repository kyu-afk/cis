import 'package:flutter/material.dart';

class UsersAccessStsrec {
  static String code(dynamic user) {
    return (user?.stsrec ?? 'A').toString().trim().toUpperCase();
  }

  static String label(String code) {
    switch (code) {
      case 'A': return 'AKTIF';
      case 'B': return 'Blokir';
      case 'C': return 'Tutup';
      default: return code.isEmpty ? '-' : code;
    }
  }

  static String labelFor(dynamic user) => label(code(user));

  static bool isAktif(dynamic user) => code(user) == 'A';
  static bool isBlokir(dynamic user) => code(user) == 'B';

  static Color badgeColor(String code) {
    switch (code) {
      case 'A': return Colors.green;
      case 'B': return Colors.orange;
      case 'C': return Colors.blueGrey;
      default: return Colors.grey;
    }
  }
}