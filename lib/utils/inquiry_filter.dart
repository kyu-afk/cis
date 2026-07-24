import '../pref/pref.dart';

/// Filter hasil inquiry berdasarkan bpr_id & kode_kantor milik user yang
/// sedang login, supaya user tidak bisa melihat data BPR/kantor lain
/// meskipun (karena satu dan lain hal) data tsb ikut terbawa di response API.
///
/// PENTING:
/// - Filter bpr_id HANYA dipakai kalau request inquiry-nya memang mengirim
///   bpr_id (parameter [sentBprId] = true).
/// - Filter kode_kantor HANYA dipakai kalau request inquiry-nya memang
///   mengirim kode_kantor (parameter [sentKodeKantor] = true).
/// - Kalau parameter itu tidak dikirim di request, filter yang bersangkutan
///   TIDAK diaktifkan. Ini untuk menghindari semua data hilang karena
///   dianggap null saat memang inquiry-nya tidak mengirim bpr_id/kode_kantor.
/// - Kode kantor "000" (kantor pusat) di-skip dari filter kode_kantor karena
///   berarti user tsb punya akses ke semua kantor.
class InquiryFilter {
  InquiryFilter._();

  /// Terapkan filter ke [data] (list of map hasil decode response).
  ///
  /// [sentBprId]      : true kalau body request inquiry ini mengirim bpr_id.
  /// [sentKodeKantor]  : true kalau body request inquiry ini mengirim kode_kantor.
  static Future<List<dynamic>> apply(
    List<dynamic> data, {
    bool sentBprId = false,
    bool sentKodeKantor = false,
  }) async {
    // Kalau inquiry-nya sama sekali tidak mengirim bpr_id maupun kode_kantor,
    // jangan filter apa-apa (biar tidak salah kena filter dengan nilai null).
    if (!sentBprId && !sentKodeKantor) return data;
    if (data.isEmpty) return data;

    final session = await Pref().getUsers();
    return applyWithSession(
      data,
      sessionBprId: session.bprId,
      sessionKodeKantor: session.kodeKantor,
      sentBprId: sentBprId,
      sentKodeKantor: sentKodeKantor,
    );
  }

  /// Versi sinkron, dipakai kalau session sudah tersedia di pemanggil
  /// (menghindari pemanggilan Pref().getUsers() berulang kali).
  static List<dynamic> applyWithSession(
    List<dynamic> data, {
    required String sessionBprId,
    required String sessionKodeKantor,
    bool sentBprId = false,
    bool sentKodeKantor = false,
  }) {
    if (!sentBprId && !sentKodeKantor) return data;
    if (data.isEmpty) return data;

    final applyBprFilter = sentBprId && sessionBprId.isNotEmpty;
    final applyKantorFilter = sentKodeKantor &&
        sessionKodeKantor.isNotEmpty &&
        sessionKodeKantor != "000";

    if (!applyBprFilter && !applyKantorFilter) return data;

    return data.where((item) {
      if (item is! Map) return true; // bentuk tidak dikenal, biarkan lolos

      if (applyBprFilter) {
        final itemBprId = _readField(item, const ['bpr_id', 'bprId', 'kd_bank', 'kode_bank']);
        // Kalau field-nya tidak ada di item, jangan digugurkan (bukan tanggung
        // jawab filter ini kalau API tidak mengembalikan bpr_id).
        if (itemBprId != null && itemBprId.isNotEmpty && itemBprId != sessionBprId) {
          return false;
        }
      }

      if (applyKantorFilter) {
        final itemKodeKantor = _readField(item, const ['kode_kantor', 'kodeKantor', 'kd_kantor']);
        if (itemKodeKantor != null && itemKodeKantor.isNotEmpty && itemKodeKantor != sessionKodeKantor) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  static String? _readField(Map item, List<String> keys) {
    for (final k in keys) {
      if (item.containsKey(k) && item[k] != null) {
        final v = item[k].toString();
        if (v.isNotEmpty) return v;
      }
    }
    return null;
  }
}
