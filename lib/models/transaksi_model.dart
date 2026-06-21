// lib/models/transaksi_model.dart

class TransaksiModel {
  final String? noHp;
  final String? norekening;
  final String? jumlah;
  final String? biayaLayanan;
  final String? noreff;
  final String? tglTrans;
  final String? keterangan;
  final String? status;
  final String? responseCore;
  final String? trxCode;
  final String? trxType;
  final String? feeBpr;

  TransaksiModel({
    this.noHp,
    this.norekening,
    this.jumlah,
    this.biayaLayanan,
    this.noreff,
    this.tglTrans,
    this.keterangan,
    this.status,
    this.responseCore,
    this.trxCode,
    this.trxType,
    this.feeBpr,
  });

  factory TransaksiModel.fromJson(Map<String, dynamic> json) {
    return TransaksiModel(
      noHp: json['nohp']?.toString() ?? json['no_hp']?.toString() ?? '',
      norekening: json['no_rek']?.toString() ??'',
      jumlah: json['amount']?.toString() ?? json['jumlah']?.toString() ?? '',
      biayaLayanan: json['biaya_layanan']?.toString() ?? '',
      noreff: json['noreff']?.toString() ?? '',
      tglTrans: json['tgl_trans']?.toString() ?? '',
      keterangan: json['keterangan']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      responseCore: json['response_core']?.toString() ?? '',
      trxCode: json['trx_code']?.toString() ?? '',
      trxType: json['trx_type']?.toString() ?? '',
      feeBpr: json['fee_bpr']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nohp': noHp ?? '',
      'no_rek': norekening ?? '',
      'amount': jumlah ?? '',
      'biaya_layanan': biayaLayanan ?? '',
      'noreff': noreff ?? '',
      'tgl_trans': tglTrans ?? '',
      'keterangan': keterangan ?? '',
      'status': status ?? '',
      'response_core': responseCore ?? '',
      'trx_code': trxCode ?? '',
      'trx_type': trxType ?? '',
      'fee_bpr': feeBpr ?? '',
    };
  }
}