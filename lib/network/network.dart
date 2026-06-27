import 'package:flutter/material.dart';

const token = "715f8ab555438f985b579844ea227767";
const xusername = "core@2023";
const xpassword = "corevalue@20231234";
const String apiKeymiddlewarecis =
    String.fromEnvironment('MIDDLEWARE_CIS_API_KEY', defaultValue: 'rahasia');
const url = "https://ibprservices.medtrans.id";
const url2 = "https://infoservices.medtrans.id";
const url_go = "https://api-dev-cms.medtrans.id";
const String _wsBaseUrlOverride =
    String.fromEnvironment('WS_BASE_URL', defaultValue: '');

String get url_go3 {
  if (_wsBaseUrlOverride.trim().isNotEmpty) {
    return _wsBaseUrlOverride.trim();
  }
  return "https://web-service-cis.medtrans.id";
}

double width(BuildContext context) {
  return MediaQuery.of(context).size.width;
}

double height(BuildContext context) {
  return MediaQuery.of(context).size.height;
}

/// PATCH: Semua endpoint url_go3 sekarang memakai prefix /cis/
class NetworkURL {
  // ---------- Auth ----------
  static String login() => "$url_go3/cis/user/login";
  static String logout()      => "$url_go3/cis/user/logout";
  static String forceLogout() => "$url_go3/cis/user/force-logout";

  static String gantipassword() => "$url_go3/cis/user/change-password";

  // ---------- Users ----------
  static String inquiryUsers() => "$url_go3/cis/user/inquiry";
  static String insertUsers() => "$url_go3/cis/user/insert";
  static String updateUsers() => "$url_go3/cis/user/update";

  // Endpoint tutup di backend route-nya adalah /cis/user/close
  static String deleteUsers() => "$url_go3/cis/user/close";
  static String closeUsers() => "$url_go3/cis/user/close";

  static String blokirUsers() => "$url_go3/cis/user/blokir";
  static String unblokirUsers() => "$url_go3/cis/user/unblokir";
  static String changePassword() => "$url_go3/cis/user/change-password";
  
  // TAMBAHKAN RESET PASSWORD
  static String resetPasswordUser() => "$url_go3/cis/user/reset-password";

  // ---------- Collector (Petugas) ----------
  static String inquiryCollector() => "$url_go3/cis/collector/inquiry";
  static String inquiryCollectorDb() => "$url_go3/cis/collector/inquiry-db";
  static String resolveUserIdCollector() => "$url_go3/cis/collector/resolve-userid";
  static String syncRepairCollector()   => "$url_go3/cis/collector/sync-repair";
  static String syncBackfillCollector() => "$url_go3/cis/collector/sync-backfill";
  static String insertCollector() => "$url_go3/cis/collector/insert";
  static String updateCollector() => "$url_go3/cis/collector/update";
  static String deleteCollector() => "$url_go3/cis/collector/delete";
  static String blokirCollector()          => "$url_go3/cis/collector/blokir";
  static String unblokirCollector()        => "$url_go3/cis/collector/unblokir";
  static String resetPasswordCollector()   => "$url_go3/cis/collector/reset-password";
  static String bukaTransaksiCollector()   => "$url_go3/cis/collector/buka-transaksi";
  static String tutupTransaksiCollector()  => "$url_go3/cis/collector/tutup-transaksi";

  // ---------- MPIN Collector ----------
  static String generateMpin() => "$url_go3/cis/mpin/generate";
  static String regenerateMpin() => "$url_go3/cis/mpin/regenerate";
  static String resetMpin() => "$url_go3/cis/mpin/reset";
  static String cetakMpin() => "$url_go3/cis/mpin/cetak";

  // ---------- Teller ----------
  static String inquiryTeller()  => "$url_go3/cis/teller/inquiry";
  static String insertTeller()   => "$url_go3/cis/teller/insert";
  static String updateTeller()   => "$url_go3/cis/teller/update";
  static String deleteTeller()   => "$url_go3/cis/teller/delete";
  static String blokirTeller()          => "$url_go3/cis/teller/blokir";
  static String unblokirTeller()        => "$url_go3/cis/teller/unblokir";
  static String resetPasswordTeller()   => "$url_go3/cis/teller/reset-password";
  static String resolveUserIdTeller()   => "$url_go3/cis/teller/resolve-userid";
  static String syncRepairTeller()      => "$url_go3/cis/teller/sync-repair";
  static String syncBackfillTeller()    => "$url_go3/cis/teller/sync-backfill";
  static String bukaTransaksiTeller()   => "$url_go3/cis/teller/buka-transaksi";
  static String tutupTransaksiTeller()  => "$url_go3/cis/teller/tutup-transaksi";
  static String limitInquiryTeller()    => "$url_go3/cis/teller/limit-inquiry";
  static String limitSaveTeller()       => "$url_go3/cis/teller/limit-save";
  static String limitInquiryCollector() => "$url_go3/cis/collector/limit-inquiry";
  static String limitSaveCollector()    => "$url_go3/cis/collector/limit-save";
 
  // ---------- Pengisian Modal ----------
  static String inquiryPengisianModal()  => "$url_go3/cis/pengisian-modal/inquiry";
  static String addPengisianModal()      => "$url_go3/cis/pengisian-modal/add";
  static String deletePengisianModal()   => "$url_go3/cis/pengisian-modal/delete";
  static String transaksiPengisianModal() => "$url_go3/cis/pengisian-modal/transaksi";

  // ---------- Setup Limit ----------
  static String inquirySetupLimit() => "$url_go3/cis/setup-limit/inquiry";
  static String editSetupLimit()    => "$url_go3/cis/setup-limit/edit";

  // ---------- Setup Transaksi ----------
  static String inquirySetupTransaksi() => "$url_go3/cis/setup-transaksi/inquiry";
  static String saveSetupTransaksi()    => "$url_go3/cis/setup-transaksi/save";

  // ---------- TCode ----------
  static String listTcode() => "$url_go/tcode";


  // ---------- Transaksi Petugas  ----------
  static String inquiryTransaksi() => "$url_go3/cis/transaksi/inquiry";

  // ---------- SBB Perantara ----------
  static String inquirySbbPerantara() => "$url_go3/cis/sbb-perantara/inquiry";
  static String addSbbPerantara()     => "$url_go3/cis/sbb-perantara/add";
  static String editSbbPerantara()    => "$url_go3/cis/sbb-perantara/edit";
  static String deleteSbbPerantara()  => "$url_go3/cis/sbb-perantara/delete";

  // ---------- Modal Kolektor ----------
  static String inquiryModalKolektor()    => "$url_go3/cis/modal-kolektor/inquiry";
  static String getPendingModalKolektor() => "$url_go3/cis/modal-kolektor/get-pending";
  static String addModalKolektor()        => "$url_go3/cis/modal-kolektor/add";
  static String berikanModalKolektor()    => "$url_go3/cis/modal-kolektor/berikan";
  static String deleteModalKolektor()     => "$url_go3/cis/modal-kolektor/delete";

  // ---------- Legacy CMS (tetap) ----------
  static String getUsersAccess() => "$url_go/user_search";
  static String getListKantorAccess() => "$url_go/kantor";
  static String insertKantorCMS() => "$url_go/kantor";
  static String updateKantorCMS() => "$url_go/kantor";
  static String deleteKantorCMS() => "$url_go/kantor";
  static String getListFasilitas() => "$url_go/master_menu";
  static String inquiryAccount() => "$url_go/inquiry_account";
}