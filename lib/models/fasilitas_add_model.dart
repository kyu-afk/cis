import 'package:flutter/foundation.dart';


@immutable
class FasilitasAddModel {
  const FasilitasAddModel({
    required this.modul,
    required this.menu,
    required this.submenu,
    required this.subsubmenu,
    required this.urut,
    required this.flag,
  });

  final String modul;
  final String menu;
  final String submenu;
  final String subsubmenu;
  final String urut;
  final String flag;

  factory FasilitasAddModel.fromJson(Map<String, dynamic> json) => FasilitasAddModel(
        modul: json['modul'].toString(),
        menu: json['menu'].toString(),
        submenu: json['submenu'].toString(),
        subsubmenu: json['subsubmenu'].toString(),
        urut: json['urut'].toString(),
        flag: (json['flag'] ?? '').toString().toUpperCase().trim(),
      );

  Map<String, dynamic> toJson() => {'modul': modul, 'menu': menu, 'submenu': submenu, 'subsubmenu': subsubmenu, 'urut': urut, 'flag': flag};

  FasilitasAddModel clone() => FasilitasAddModel(modul: modul, menu: menu, submenu: submenu, subsubmenu: subsubmenu, urut: urut, flag: flag);

  FasilitasAddModel copyWith({String? modul, String? menu, String? submenu, String? subsubmenu, String? urut, String? flag}) => FasilitasAddModel(
        modul: modul ?? this.modul,
        menu: menu ?? this.menu,
        submenu: submenu ?? this.submenu,
        subsubmenu: subsubmenu ?? this.subsubmenu,
        urut: urut ?? this.urut,
        flag: flag ?? this.flag,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FasilitasAddModel &&
          modul == other.modul &&
          menu == other.menu &&
          submenu == other.submenu &&
          subsubmenu == other.subsubmenu &&
          urut == other.urut &&
          flag == other.flag;

  @override
  int get hashCode => modul.hashCode ^ menu.hashCode ^ submenu.hashCode ^ subsubmenu.hashCode ^ urut.hashCode ^ flag.hashCode;
}
