/// Utility terpusat untuk manajemen level user di CIS.
///
/// Level mapping (dari field `lvluser` di response login):
///   lvl 1 → User Biasa    : akses menu sesuai fasilitas, hanya data kode kantor sendiri
///   lvl 2 → Super Admin   : bypass semua fasilitas menu, bisa lihat semua kode kantor
///   lvl 3 → System        : hanya Kantor + User Access, bisa lihat semua kode kantor
///
/// Kode kantor 000 (khusus super admin / system) tidak pernah muncul di list user access.

import '../models/users_model.dart';

enum UserLevel {
  /// lvluser = 1 — user operasional biasa
  biasa,

  /// lvluser = 2 — super admin, akses penuh tanpa setting fasilitas
  superAdmin,

  /// lvluser = 3 — system, hanya menu Kantor & User Access, akses semua kantor
  system,
}

class UserLevelHelper {
  const UserLevelHelper._();

  // ─── Parser ───────────────────────────────────────────────────────────────

  static UserLevel fromInt(int lvl) {
    switch (lvl) {
      case 2:  return UserLevel.superAdmin;
      case 3:  return UserLevel.system;
      default: return UserLevel.biasa;
    }
  }

  static UserLevel fromUsers(UsersModel? users) {
    return fromInt(users?.lvlUser ?? 1);
  }

  // ─── Predicate helpers ───────────────────────────────────────────────────

  /// lvl 2: super admin — bypass semua akses menu, lihat semua kantor
  static bool isSuperAdmin(UsersModel? users) =>
      fromUsers(users) == UserLevel.superAdmin;

  /// lvl 3: system — hanya Kantor + User Access, lihat semua kantor
  static bool isSystem(UsersModel? users) =>
      fromUsers(users) == UserLevel.system;

  /// lvl 2 atau lvl 3: keduanya bisa melihat semua kode kantor di data
  static bool canSeeAllKantor(UsersModel? users) {
    final lvl = fromUsers(users);
    return lvl == UserLevel.superAdmin || lvl == UserLevel.system;
  }

  /// lvl 1: hanya lihat data kode kantornya sendiri
  static bool isFilteredByKantor(UsersModel? users) =>
      !canSeeAllKantor(users);

  /// Kode kantor 000 tidak boleh muncul di list User Access
  static bool shouldHideFromUserList(UsersModel? users) =>
      (users?.kodeKantor ?? '') == '000';

  /// Apakah menu tertentu boleh diakses oleh level system (lvl 3)?
  /// System hanya boleh akses: Kantor dan User Access.
  static bool systemCanAccessMenu(String menu) {
    final key = menu.trim().toUpperCase();
    return key == 'KANTOR' || key == 'USER ACCESS';
  }

  /// Super admin bypass semua aturan fasilitas (selalu true).
  /// System hanya boleh menu Kantor dan User Access.
  /// User biasa tunduk pada listFasilitas.
  static bool bypassFasilitas(UsersModel? users) =>
      isSuperAdmin(users);

  // ─── Kode kantor filter untuk list data ──────────────────────────────────

  /// Kembalikan kode kantor user session.
  /// Jika bisa lihat semua kantor, return null (tidak perlu filter).
  static String? filterKdKantor(UsersModel? users) {
    if (canSeeAllKantor(users)) return null;
    return users?.kodeKantor;
  }

  /// Filter list generik berdasarkan kode kantor.
  /// [getKdKantor] adalah fungsi yang mengambil kode kantor dari item.
  static List<T> applyKantorFilter<T>({
    required List<T> list,
    required UsersModel? users,
    required String? Function(T item) getKdKantor,
  }) {
    final filterKd = filterKdKantor(users);
    if (filterKd == null) return list; // lihat semua
    return list.where((item) => getKdKantor(item) == filterKd).toList();
  }

  // ─── Label untuk debugging ───────────────────────────────────────────────

  static String label(UsersModel? users) {
    switch (fromUsers(users)) {
      case UserLevel.superAdmin: return 'Super Admin (lvl2)';
      case UserLevel.system:     return 'System (lvl3)';
      case UserLevel.biasa:      return 'User Biasa (lvl1)';
    }
  }
}