class HrmOfficeModel {
  final String? id;
  final String? branchCode;
  final String? name;
  final String? branchType;

  HrmOfficeModel({this.id, this.branchCode, this.name, this.branchType});

  factory HrmOfficeModel.fromJson(Map<String, dynamic> json) {
    return HrmOfficeModel(
      id: json['id']?.toString(),
      branchCode: json['branch_code']?.toString() ?? json['kd_kantor']?.toString(),
      name: json['name']?.toString() ?? json['nama_kantor']?.toString(),
      branchType: json['branch_type']?.toString(),
    );
  }
}

class HrmEmployeeModel {
  final String id;
  final String name;
  final String? nik;
  final String? department;
  final String? position;
  final HrmOfficeModel? office;

  HrmEmployeeModel({
    required this.id,
    required this.name,
    this.nik,
    this.department,
    this.position,
    this.office,
  });

  factory HrmEmployeeModel.fromJson(Map<String, dynamic> json) {
    HrmOfficeModel? office;
    if (json['office'] is Map) {
      office = HrmOfficeModel.fromJson(Map<String, dynamic>.from(json['office'] as Map));
    }
    return HrmEmployeeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['nama']?.toString() ?? '',
      nik: json['nik']?.toString(),
      department: json['department']?.toString() ?? json['departemen']?.toString(),
      position: json['position']?.toString() ?? json['jabatan']?.toString(),
      office: office,
    );
  }

  String? get tanggalLahirFromNik {
    if (nik == null || nik!.length < 12) return null;
    try {
      int day = int.parse(nik!.substring(6, 8));
      if (day > 40) day -= 40;
      final month = int.parse(nik!.substring(8, 10));
      final yearSuffix = int.parse(nik!.substring(10, 12));
      final year = yearSuffix <= 25 ? 2000 + yearSuffix : 1900 + yearSuffix;
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
      ];
      if (month < 1 || month > 12) return null;
      return '${day.toString().padLeft(2, '0')} ${months[month - 1]} $year';
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => name;
}
