import 'package:flutter/foundation.dart';

@immutable
class FasilitasModel {
  const FasilitasModel({
    required this.modul,
    required this.menu,
    required this.submenu,
    required this.subsubmenu,
    required this.urut,
    this.isActive = false,
  });

  final String modul;
  final String menu;
  final String submenu;
  final String subsubmenu;
  final String urut;
  final bool isActive;  // TAMBAHKAN

  factory FasilitasModel.fromJson(Map<String, dynamic> json) => FasilitasModel(
    modul: json['modul'].toString(),
    menu: json['menu'].toString(),
    submenu: json['submenu'].toString(),
    subsubmenu: json['subsubmenu'].toString(),
    urut: json['urut'].toString(),
    isActive: json['is_active'] == true || json['is_active'] == 'Y' || json['is_active'] == 1,
  );

  Map<String, dynamic> toJson() => {
    'modul': modul,
    'menu': menu,
    'submenu': submenu,
    'subsubmenu': subsubmenu,
    'urut': urut,
    'is_active': isActive,
  };

  FasilitasModel clone() => FasilitasModel(
    modul: modul,
    menu: menu,
    submenu: submenu,
    subsubmenu: subsubmenu,
    urut: urut,
    isActive: isActive,
  );

  FasilitasModel copyWith({
    String? modul,
    String? menu,
    String? submenu,
    String? subsubmenu,
    String? urut,
    bool? isActive,
  }) => FasilitasModel(
    modul: modul ?? this.modul,
    menu: menu ?? this.menu,
    submenu: submenu ?? this.submenu,
    subsubmenu: subsubmenu ?? this.subsubmenu,
    urut: urut ?? this.urut,
    isActive: isActive ?? this.isActive,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FasilitasModel &&
          modul == other.modul &&
          menu == other.menu &&
          submenu == other.submenu &&
          subsubmenu == other.subsubmenu;

  @override
  int get hashCode => modul.hashCode ^ menu.hashCode ^ submenu.hashCode ^ subsubmenu.hashCode ^ urut.hashCode;
}