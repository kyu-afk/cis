// lib/models/hari_libur_model.dart

class HariLiburModel {
  final int id;
  final bool isActive;
  // 'libur_nasional' | 'cuti_bersama' | 'libur_khusus'
  final String jenis;
  final String keterangan;
  final String tanggal; // format: YYYY-MM-DD
  // Cuma keisi untuk jenis 'libur_khusus'.
  final List<String> bprIds;

  HariLiburModel({
    required this.id,
    required this.isActive,
    required this.jenis,
    required this.keterangan,
    required this.tanggal,
    required this.bprIds,
  });

  factory HariLiburModel.fromJson(Map<String, dynamic> json) {
    return HariLiburModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      isActive: json['is_active'] == true,
      jenis: (json['jenis'] ?? '').toString(),
      keterangan: (json['keterangan'] ?? '').toString(),
      tanggal: (json['tanggal'] ?? '').toString(),
      bprIds: (json['bpr_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  /// libur_nasional & cuti_bersama berlaku untuk SEMUA BPR.
  /// libur_khusus cuma berlaku untuk BPR yang ada di [bprIds].
  bool appliesToBpr(String bprId) {
    switch (jenis) {
      case 'libur_nasional':
      case 'cuti_bersama':
        return true;
      case 'libur_khusus':
        return bprIds.contains(bprId);
      default:
        return false;
    }
  }
}
