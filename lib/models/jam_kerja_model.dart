// lib/models/jam_kerja_model.dart

class JamKerjaModel {
  // 1 = Senin, ..., 7 = Minggu — sama persis dengan DateTime.weekday di Dart.
  final int hari;
  final String hariNama;
  final bool isLibur;
  // Sengaja TIDAK dipakai untuk validasi login (jam_buka/jam_tutup) —
  // beberapa karyawan masih lembur di luar jam itu. Cuma is_libur yang
  // dipakai: kalau hari itu libur, dari awal hari memang gak boleh dipakai
  // sama sekali, gak peduli jamnya.
  final String jamBuka;
  final String jamTutup;

  JamKerjaModel({
    required this.hari,
    required this.hariNama,
    required this.isLibur,
    required this.jamBuka,
    required this.jamTutup,
  });

  factory JamKerjaModel.fromJson(Map<String, dynamic> json) {
    return JamKerjaModel(
      hari: json['hari'] is int ? json['hari'] : int.tryParse('${json['hari']}') ?? 0,
      hariNama: (json['hari_nama'] ?? '').toString(),
      isLibur: json['is_libur'] == true,
      jamBuka: (json['jam_buka'] ?? '').toString(),
      jamTutup: (json['jam_tutup'] ?? '').toString(),
    );
  }
}
