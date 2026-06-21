import 'package:flutter/foundation.dart';


@immutable
class SandiBankModel {

  const SandiBankModel({
    required this.id,
    required this.nama,
    required this.jenis,
    required this.tipe,
    required this.kodeBank,
  });

  final String id;
  final String nama;
  final String jenis;
  final String tipe;
  final String kodeBank;

  factory SandiBankModel.fromJson(Map<String,dynamic> json) => SandiBankModel(
    id: json['id'].toString(),
    nama: json['nama'].toString(),
    jenis: json['jenis'].toString(),
    tipe: json['tipe'].toString(),
    kodeBank: json['kode_bank'].toString()
  );
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'jenis': jenis,
    'tipe': tipe,
    'kode_bank': kodeBank
  };

  SandiBankModel clone() => SandiBankModel(
    id: id,
    nama: nama,
    jenis: jenis,
    tipe: tipe,
    kodeBank: kodeBank
  );


  SandiBankModel copyWith({
    String? id,
    String? nama,
    String? jenis,
    String? tipe,
    String? kodeBank
  }) => SandiBankModel(
    id: id ?? this.id,
    nama: nama ?? this.nama,
    jenis: jenis ?? this.jenis,
    tipe: tipe ?? this.tipe,
    kodeBank: kodeBank ?? this.kodeBank,
  );

  @override
  bool operator ==(Object other) => identical(this, other)
    || other is SandiBankModel && id == other.id && nama == other.nama && jenis == other.jenis && tipe == other.tipe && kodeBank == other.kodeBank;

  @override
  int get hashCode => id.hashCode ^ nama.hashCode ^ jenis.hashCode ^ tipe.hashCode ^ kodeBank.hashCode;
}
