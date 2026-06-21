import 'package:flutter/foundation.dart';
import 'package:quiver/core.dart';

import 'index.dart';

@immutable
class KantorModel {
  const KantorModel({
    required this.bpr_id,
    required this.kdKantor,
    required this.namaKantor,
  });

  final dynamic bpr_id;
  final dynamic kdKantor;
  final dynamic namaKantor;

  factory KantorModel.fromJson(Map<String, dynamic> json) =>
      KantorModel(bpr_id: json['bpr_id'] as dynamic, kdKantor: json['kd_kantor'] as dynamic, namaKantor: json['nama_kantor'] as dynamic);

  Map<String, dynamic> toJson() => {'bpr_id': bpr_id, 'kd_kantor': kdKantor, 'nama_kantor': namaKantor};

  KantorModel clone() => KantorModel(bpr_id: bpr_id, kdKantor: kdKantor, namaKantor: namaKantor);

  KantorModel copyWith({dynamic? bpr_id, dynamic? kdKantor, dynamic? namaKantor}) => KantorModel(
        bpr_id: bpr_id ?? this.bpr_id,
        kdKantor: kdKantor ?? this.kdKantor,
        namaKantor: namaKantor ?? this.namaKantor,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is KantorModel && bpr_id == other.bpr_id && kdKantor == other.kdKantor && namaKantor == other.namaKantor;

  @override
  int get hashCode => bpr_id.hashCode ^ kdKantor.hashCode ^ namaKantor.hashCode;
}
