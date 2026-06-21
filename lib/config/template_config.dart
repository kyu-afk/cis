/// Konfigurasi mode template — ubah di sini saat membuat proyek baru.
class TemplateConfig {
  /// `true`: aplikasi langsung ke menu tanpa halaman login.
  /// `false`: wajib login seperti aplikasi produksi.
  static const bool skipLogin = false; // ← DIMATIKAN: sekarang pakai login sungguhan

  /// `true`: tampilkan semua menu tanpa cek izin (khusus development).
  /// Set `false` sebelum build produksi / uji login sungguhan.
  static const bool superAccess = false; // ← DIMATIKAN: akses dikontrol dari backend

  static const String bprId = '609999';
  static const String usersId = 'TEMPLATE';
  static const String namaUsers = 'Template Admin';
  static const String kodeKantor = '000';
  static const String namaKantor = 'Kantor Pusat';

  static const List<Map<String, String>> defaultAkses = [
    {
      'modul': 'CMS',
      'menu': 'USER ACCESS',
      'submenu': 'USER ACCESS',
      'subsubmenu': '',
      'urut': '1',
      'flag': 'TRUE',
    },
    {
      'modul': 'CMS',
      'menu': 'KANTOR',
      'submenu': 'KANTOR',
      'subsubmenu': '',
      'urut': '2',
      'flag': 'TRUE',
    },
  ];
}