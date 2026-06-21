import 'package:flutter/material.dart';
 
class DataTellerStsrec {
  static const String AKTIF  = 'aktif';
  static const String BLOKIR = 'blokir';
  static const String HAPUS  = 'hapus';
 
  static String code(dynamic teller) {
    return (teller?.status ?? 'aktif').toString().trim().toLowerCase();
  }
 
  static String getLabel(String code) {
    switch (code) {
      case AKTIF:  return 'AKTIF';
      case BLOKIR: return 'BLOKIR';
      case HAPUS:  return 'HAPUS';
      default:     return 'AKTIF';
    }
  }
 
  static String statusFor(dynamic teller) => getLabel(code(teller));
 
  static bool isAktif(dynamic teller)  => code(teller) == AKTIF;
  static bool isBlokir(dynamic teller) => code(teller) == BLOKIR;
  static bool isTidakAktif(dynamic teller) => code(teller) != AKTIF;

  // Kebalikan getLabel — dari label ke code
  static String codeFromLabel(String label) {
    switch (label.toUpperCase()) {
      case 'AKTIF':  return AKTIF;
      case 'BLOKIR': return BLOKIR;
      case 'HAPUS':  return HAPUS;
      default:       return AKTIF;
    }
  }
 
  static Color badgeColor(String code) {
    switch (code) {
      case AKTIF:  return Colors.green;
      case BLOKIR: return Colors.orange;
      case HAPUS:  return Colors.red;
      default:     return Colors.green;
    }
  }
}