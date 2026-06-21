// models/users_access_model.dart
class UsersAccessModel {
  String? userid;
  String? namauser;
  String? pass;
  String? kdbank;
  String? kdkantor;
  String? namaKantor;  // TAMBAHKAN FIELD UNTUK NAMA KANTOR
  String? tglexp;
  String? stsaktif;
  String? stsrec;
  String? tglinput;
  String? tglubah;
  String? userinput;
  String? userubah;
  int? lvluser;
  int? passSalah;
  String? tglhapus;
  String? userhapus;
  String? termBlokir;
  String? terminalId;
  String? tglBlokir;
  String? userBlokir;
  String? batch;
  String? bedaKantor;
  String? fhoto1;
  String? fhoto2;
  String? fhoto3;
  String? level;
  String? namaSbb;
  String? sbbTeller;
  String? aksesTeller;
  int? maxOtor;
  int? minOtor;
  int? stslogin;
  List<AksesModel>? akses;

  UsersAccessModel({
    this.userid,
    this.namauser,
    this.pass,
    this.kdbank,
    this.kdkantor,
    this.namaKantor,  // TAMBAHKAN
    this.tglexp,
    this.stsaktif,
    this.stsrec,
    this.tglinput,
    this.tglubah,
    this.userinput,
    this.userubah,
    this.lvluser,
    this.passSalah,
    this.tglhapus,
    this.userhapus,
    this.termBlokir,
    this.terminalId,
    this.tglBlokir,
    this.userBlokir,
    this.batch,
    this.bedaKantor,
    this.fhoto1,
    this.fhoto2,
    this.fhoto3,
    this.level,
    this.namaSbb,
    this.sbbTeller,
    this.aksesTeller,
    this.maxOtor,
    this.minOtor,
    this.stslogin,
    this.akses,
  });

  factory UsersAccessModel.fromJson(Map<String, dynamic> json) {
    // Helper: baca key lowercase ATAU PascalCase (untuk kompatibilitas response Go)
    T? get<T>(String lower, String pascal) {
      final val = json[lower] ?? json[pascal];
      if (val == null) return null;
      if (T == String) return val.toString() as T;
      return val as T;
    }

    List<AksesModel> aksesList = [];
    final rawAkses = json['akses'] ?? json['Akses'];
    if (rawAkses != null && rawAkses is List) {
      aksesList = (rawAkses)
          .map((e) => AksesModel.fromJson(e))
          .toList();
    }

    // Baca int dengan fallback PascalCase
    int? parseInt(String lower, String pascal) {
      final val = json[lower] ?? json[pascal];
      if (val is int) return val;
      return int.tryParse(val?.toString() ?? '');
    }

    return UsersAccessModel(
      userid: (json['userid'] ?? json['UserID'])?.toString(),
      namauser: (json['namauser'] ?? json['NamaUser'] ?? json['nama'])?.toString(),
      pass: (json['pass'] ?? json['Password'])?.toString(),
      kdbank: (json['kdbank'] ?? json['bpr_id'] ?? json['BprID'])?.toString(),
      kdkantor: (json['kdkantor'] ?? json['kd_kantor'] ?? json['KdKantor'])?.toString(),
      namaKantor: (json['nama_kantor'] ?? json['namakantor'] ?? json['NamaKantor'])?.toString(),
      tglexp: (json['tglexp'] ?? json['TglExp'] ?? json['last_login'] ?? json['LastLogin'])?.toString(),
      stsaktif: (json['stsaktif'] ?? json['StsAktif'])?.toString(),
      // stsrec: backend CMS menggunakan kolom "stsaktif" (A/B/C/D).
      // Fallback ke stsaktif agar status di tabel tidak selalu "AKTIF".
      stsrec: (json['stsrec'] ?? json['StsRec'] ?? json['stsaktif'] ?? json['StsAktif'])?.toString(),
      tglinput: (json['tglinput'] ?? json['created_at'] ?? json['CreatedAt'])?.toString(),
      tglubah: (json['tglubah'] ?? json['updated_at'] ?? json['UpdatedAt'])?.toString(),
      userinput: (json['userinput'] ?? json['created_by'] ?? json['CreatedBy'])?.toString(),
      userubah: (json['userubah'] ?? json['updated_by'] ?? json['UpdatedBy'])?.toString(),
      lvluser: parseInt('lvluser', 'LvlUser'),
      passSalah: parseInt('pass_salah', 'PassSalah'),
      tglhapus: (json['tglhapus'] ?? json['deleted_at'] ?? json['DeletedAt'])?.toString(),
      userhapus: (json['userhapus'] ?? json['deleted_by'] ?? json['DeletedBy'])?.toString(),
      termBlokir: (json['term_blokir'] ?? json['TermBlokir'])?.toString(),
      terminalId: (json['terminal_id'] ?? json['TerminalId'])?.toString(),
      tglBlokir: (json['tgl_blokir'] ?? json['TglBlokir'])?.toString(),
      userBlokir: (json['user_blokir'] ?? json['UserBlokir'])?.toString(),
      batch: (json['batch'] ?? json['Batch'])?.toString(),
      bedaKantor: (json['beda_kantor'] ?? json['BedaKantor'])?.toString(),
      fhoto1: (json['fhoto_1'] ?? json['Fhoto1'])?.toString(),
      fhoto2: (json['fhoto_2'] ?? json['Fhoto2'])?.toString(),
      fhoto3: (json['fhoto_3'] ?? json['Fhoto3'])?.toString(),
      level: (json['level'] ?? json['Level'])?.toString(),
      namaSbb: (json['nama_sbb'] ?? json['NamaSbb'])?.toString(),
      sbbTeller: (json['sbb_teller'] ?? json['SbbTeller'])?.toString(),
      aksesTeller: (json['akses_teller'] ?? json['AksesTeller'])?.toString(),
      maxOtor: parseInt('max_otor', 'MaxOtor'),
      minOtor: parseInt('min_otor', 'MinOtor'),
      stslogin: parseInt('stslogin', 'StsLogin'),
      akses: aksesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userid': userid,
      'namauser': namauser,
      'pass': pass,
      'kdbank': kdbank,
      'kdkantor': kdkantor,
      'nama_kantor': namaKantor,  // TAMBAHKAN
      'tglexp': tglexp,
      'stsaktif': stsaktif,
      'stsrec': stsrec,
      'tglinput': tglinput,
      'tglubah': tglubah,
      'userinput': userinput,
      'userubah': userubah,
      'lvluser': lvluser,
      'pass_salah': passSalah,
      'tglhapus': tglhapus,
      'userhapus': userhapus,
      'term_blokir': termBlokir,
      'terminal_id': terminalId,
      'tgl_blokir': tglBlokir,
      'user_blokir': userBlokir,
      'batch': batch,
      'beda_kantor': bedaKantor,
      'fhoto_1': fhoto1,
      'fhoto_2': fhoto2,
      'fhoto_3': fhoto3,
      'level': level,
      'nama_sbb': namaSbb,
      'sbb_teller': sbbTeller,
      'akses_teller': aksesTeller,
      'max_otor': maxOtor,
      'min_otor': minOtor,
      'stslogin': stslogin,
      'akses': akses?.map((e) => e.toJson()).toList(),
    };
  }
}

class AksesModel {
  int? id;
  String? modul;
  String? menu;
  String? submenu;
  String? subsubmenu;
  int? urut;
  dynamic flag; // Bisa bool atau String
  String? userid;
  String? stsrec;
  String? tglinput;
  String? tglubah;
  String? userinput;
  String? userubah;

  AksesModel({
    this.id,
    this.modul,
    this.menu,
    this.submenu,
    this.subsubmenu,
    this.urut,
    this.flag,
    this.userid,
    this.stsrec,
    this.tglinput,
    this.tglubah,
    this.userinput,
    this.userubah,
  });

  factory AksesModel.fromJson(Map<String, dynamic> json) {
    final rawFlag = json['flag'] ?? json['Flag'];
    bool flagValue = false;
    if (rawFlag is bool) {
      flagValue = rawFlag;
    } else if (rawFlag != null) {
      flagValue = rawFlag.toString().toUpperCase() == 'TRUE';
    }

    return AksesModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0'),
      modul: (json['modul'] ?? json['Modul'])?.toString(),
      menu: (json['menu'] ?? json['Menu'])?.toString(),
      submenu: (json['submenu'] ?? json['Submenu'])?.toString(),
      subsubmenu: (json['subsubmenu'] ?? json['SubSubmenu'])?.toString(),
      urut: json['urut'] is int
          ? json['urut']
          : json['Urut'] is int
              ? json['Urut']
              : int.tryParse((json['urut'] ?? json['Urut'])?.toString() ?? '0'),
      flag: flagValue,
      userid: json['userid']?.toString(),
      stsrec: json['stsrec']?.toString(),
      tglinput: json['tglinput']?.toString(),
      tglubah: json['tglubah']?.toString(),
      userinput: json['userinput']?.toString(),
      userubah: json['userubah']?.toString(),
    );
  }

  // Helper method untuk mendapatkan flag sebagai bool
  bool getFlagAsBool() {
    if (flag is bool) return flag as bool;
    if (flag is String) return flag.toString().toUpperCase() == 'TRUE';
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'modul': modul,
      'menu': menu,
      'submenu': submenu,
      'subsubmenu': subsubmenu,
      'urut': urut,
      'flag': flag,
      'userid': userid,
      'stsrec': stsrec,
      'tglinput': tglinput,
      'tglubah': tglubah,
      'userinput': userinput,
      'userubah': userubah,
    };
  }
}