// lib/models/transaksi_model.dart

class TransaksiModel {
  final String? id;
  final String? bprId;
  final String? userid;
  final String? noHp;
  final String? namaPetugas;
  final String? trxCode;
  final String? keterangan;
  final String? norekening;
  final String? noRekTujuan;
  final String? namaNasabah;
  final String? jumlah;
  final String? noRef;
  final String? rrn;
  final String? status;
  final String? errorMsg;
  final String? tglTrans;
  final String? tanggalPosting;
  final String? createdAt;

  // Field lama (dari alur middleware sebelumnya) — dipertahankan supaya
  // model ini tetap kompatibel kalau masih dipakai di tempat lain.
  final String? biayaLayanan;
  final String? responseCore;
  final String? trxType;
  final String? feeBpr;

  TransaksiModel({
    this.id,
    this.bprId,
    this.userid,
    this.noHp,
    this.namaPetugas,
    this.trxCode,
    this.keterangan,
    this.norekening,
    this.noRekTujuan,
    this.namaNasabah,
    this.jumlah,
    this.noRef,
    this.rrn,
    this.status,
    this.errorMsg,
    this.tglTrans,
    this.tanggalPosting,
    this.createdAt,
    this.biayaLayanan,
    this.responseCore,
    this.trxType,
    this.feeBpr,
  });

  // Sesuai response asli GET https://api-collme.medtrans.id/api/transaksi/today
  factory TransaksiModel.fromJson(Map<String, dynamic> json) {
    return TransaksiModel(
      id: json['id']?.toString() ?? '',
      bprId: json['bpr_id']?.toString() ?? '',
      userid: json['userid']?.toString() ?? '',
      noHp: json['nohp']?.toString() ?? json['no_hp']?.toString() ?? '',
      namaPetugas: json['nama_petugas']?.toString() ?? '',
      trxCode: json['trx_code']?.toString() ?? '',
      keterangan: json['keterangan']?.toString() ?? '',
      norekening: json['no_rek']?.toString() ?? '',
      noRekTujuan: json['no_rek_tujuan']?.toString() ?? '',
      // Nama pemilik rekening (nasabah) yang jadi lawan transaksi kolektor.
      namaNasabah: json['nama_nasabah']?.toString() ??
          json['namanasabah']?.toString() ??
          json['nama_rekening']?.toString() ??
          json['nama']?.toString() ??
          '',
      jumlah: json['amount']?.toString() ?? json['jumlah']?.toString() ?? '',
      noRef: json['no_ref']?.toString() ?? json['noreff']?.toString() ?? '',
      rrn: json['rrn']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      errorMsg: json['error_msg']?.toString() ?? '',
      tglTrans: json['tgl_trans']?.toString() ?? '',
      tanggalPosting: json['tanggal_posting']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      biayaLayanan: json['biaya_layanan']?.toString() ?? '',
      responseCore: json['response_core']?.toString() ?? '',
      trxType: json['trx_type']?.toString() ?? '',
      feeBpr: json['fee_bpr']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id ?? '',
      'bpr_id': bprId ?? '',
      'userid': userid ?? '',
      'nohp': noHp ?? '',
      'nama_petugas': namaPetugas ?? '',
      'trx_code': trxCode ?? '',
      'keterangan': keterangan ?? '',
      'no_rek': norekening ?? '',
      'no_rek_tujuan': noRekTujuan ?? '',
      'nama_nasabah': namaNasabah ?? '',
      'amount': jumlah ?? '',
      'no_ref': noRef ?? '',
      'rrn': rrn ?? '',
      'status': status ?? '',
      'error_msg': errorMsg ?? '',
      'tgl_trans': tglTrans ?? '',
      'tanggal_posting': tanggalPosting ?? '',
      'created_at': createdAt ?? '',
      'biaya_layanan': biayaLayanan ?? '',
      'response_core': responseCore ?? '',
      'trx_type': trxType ?? '',
      'fee_bpr': feeBpr ?? '',
    };
  }
}
