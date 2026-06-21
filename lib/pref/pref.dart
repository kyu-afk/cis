import 'package:cis_menu/models/index.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Pref {
  static String bprId      = "bpr_id";
  static String usersId    = "users_id";
  static String namaUsers  = "nama_users";
  static String kodeKantor = "kode_kantor";
  static String namaKantor = "nama_kantor";
  static String lvlUser    = "lvl_user";
  static String fasilitas  = "fasilitas";
  static String authToken  = "auth_token"; // token dari web service

  Future<void> simpan(UsersModel users) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    await pref.setString(Pref.bprId,      users.bprId);
    await pref.setString(Pref.usersId,    users.usersId);
    await pref.setString(Pref.namaUsers,  users.namaUsers);
    await pref.setString(Pref.kodeKantor, users.kodeKantor);
    await pref.setString(Pref.namaKantor, users.namaKantor);
    await pref.setInt(Pref.lvlUser,       users.lvlUser);
  }

  Future<void> setToken(String value) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    await pref.setString(Pref.authToken, value);
  }

  Future<String> getToken() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.getString(Pref.authToken) ?? "";
  }

  Future<void> getFasilitas_() async {}

  Future<String> getFasilitas() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.getString(Pref.fasilitas) ?? "[]";
  }

  Future<void> setFasilitas(String value) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    await pref.setString(Pref.fasilitas, value);
  }

  Future<UsersModel> getUsers() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    return UsersModel(
      bprId:      pref.getString(Pref.bprId)      ?? "",
      usersId:    pref.getString(Pref.usersId)    ?? "",
      namaUsers:  pref.getString(Pref.namaUsers)  ?? "",
      kodeKantor: pref.getString(Pref.kodeKantor) ?? "",
      namaKantor: pref.getString(Pref.namaKantor) ?? "",
      lvlUser:    pref.getInt(Pref.lvlUser)        ?? 1,
    );
  }

  // Hapus semua data termasuk fasilitas dan token (dipanggil saat logout)
  Future<void> hapus() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    await pref.remove(Pref.bprId);
    await pref.remove(Pref.usersId);
    await pref.remove(Pref.namaUsers);
    await pref.remove(Pref.kodeKantor);
    await pref.remove(Pref.namaKantor);
    await pref.remove(Pref.lvlUser);
    await pref.remove(Pref.fasilitas);
    await pref.remove(Pref.authToken);
  }

  Future<void> remove() async {
    await hapus();
  }
}