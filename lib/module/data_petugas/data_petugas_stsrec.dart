import 'package:flutter/material.dart';

class DataPetugasStsrec {
  static const String AKTIF    = 'aktif';
  static const String BLOKIR   = 'blokir';

  static String code(dynamic petugas) {
    return (petugas?.status ?? 'aktif').toString().trim().toLowerCase();
  }

  static String getLabel(String code) {
    switch (code) {
      case AKTIF:  return 'AKTIF';
      case BLOKIR: return 'BLOKIR';
      default:     return 'AKTIF';
    }
  }

  static String statusFor(dynamic petugas) => getLabel(code(petugas));
  static bool isAktif(dynamic petugas)     => code(petugas) == AKTIF;
  static bool isTidakAktif(dynamic petugas) => code(petugas) == BLOKIR;

  static Color badgeColor(String code) {
    switch (code) {
      case AKTIF:  return Colors.green;
      case BLOKIR: return Colors.orange;
      default:     return Colors.green;
    }
  }
}