class LoginResponseModel {
  final String token;
  final LoginUserDataModel user;
  final List<AksesMenuModel> akses;

  const LoginResponseModel({
    required this.token,
    required this.user,
    required this.akses,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    final rawAkses = json['akses'];
    final aksesList = <AksesMenuModel>[];

    if (rawAkses is List) {
      for (final item in rawAkses) {
        if (item is Map) {
          aksesList.add(AksesMenuModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return LoginResponseModel(
      token: json['token']?.toString() ?? '',
      user: LoginUserDataModel(
        userId:   (json['userid'] ?? json['user_id'])?.toString() ?? '',
        namaUser: (json['nama'] ?? json['namauser'])?.toString() ?? '',
        kdKantor: json['kd_kantor']?.toString() ?? '',
        bprId:    json['bpr_id']?.toString() ?? '',
      ),
      akses: aksesList,
    );
  }
}

class LoginUserDataModel {
  final String userId;
  final String namaUser;
  final String kdKantor;
  final String bprId;

  const LoginUserDataModel({
    required this.userId,
    required this.namaUser,
    required this.kdKantor,
    required this.bprId,
  });

  factory LoginUserDataModel.fromJson(Map<String, dynamic> json) {
    return LoginUserDataModel(
      userId:   (json['userid'] ?? json['user_id'])?.toString() ?? '',
      namaUser: (json['nama'] ?? json['namauser'])?.toString() ?? '',
      kdKantor: json['kd_kantor']?.toString() ?? '',
      bprId:    json['bpr_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'userid':    userId,
        'nama':      namaUser,
        'kd_kantor': kdKantor,
        'bpr_id':    bprId,
      };
}

class AksesMenuModel {
  final String modul;
  final String menu;
  final String submenu;
  final String subsubmenu;
  final int urut;
  final bool flag;

  const AksesMenuModel({
    required this.modul,
    required this.menu,
    required this.submenu,
    required this.subsubmenu,
    required this.urut,
    required this.flag,
  });

  factory AksesMenuModel.fromJson(Map<String, dynamic> json) {
    bool parseFlag(dynamic v) {
      if (v is bool) return v;
      final s = v?.toString().trim().toUpperCase() ?? '';
      return s == 'TRUE' || s == '1';
    }

    return AksesMenuModel(
      modul:      json['modul']?.toString() ?? '',
      menu:       json['menu']?.toString() ?? '',
      submenu:    json['submenu']?.toString() ?? '',
      subsubmenu: json['subsubmenu']?.toString() ?? '',
      urut:       int.tryParse(json['urut']?.toString() ?? '0') ?? 0,
      flag:       parseFlag(json['flag']),
    );
  }

  Map<String, dynamic> toFasilitasJson() => {
        'modul':      modul,
        'menu':       menu,
        'submenu':    submenu,
        'subsubmenu': subsubmenu,
        'urut':       urut.toString(),
        'flag':       flag ? 'TRUE' : 'FALSE',
      };

  Map<String, dynamic> toJson() => {
        'modul':      modul,
        'menu':       menu,
        'submenu':    submenu,
        'subsubmenu': subsubmenu,
        'urut':       urut,
        'flag':       flag,
      };
}