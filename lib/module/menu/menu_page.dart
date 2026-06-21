import 'package:cis_menu/module/dashboard/dashboard_page.dart';
import 'package:cis_menu/module/data_petugas/data_petugas_page.dart';
import 'package:cis_menu/module/data_teller/data_teller_page.dart';
import 'package:cis_menu/module/kantor/kantor_page.dart';
import 'package:cis_menu/module/kelola_kartu/data_kartu_page.dart';
import 'package:cis_menu/module/kelola_kartu/update_status_page.dart';
import 'package:cis_menu/module/laporan/laporan_transaksi_petugas_page.dart'; // 🔥 TAMBAHKAN
import 'package:cis_menu/module/menu/menu_notifier.dart';
import 'package:cis_menu/module/mpin/cetak_mpin_page.dart';
import 'package:cis_menu/module/mpin/generate_mpin_page.dart';
import 'package:cis_menu/module/mpin/regenerate_mpin_page.dart';
import 'package:cis_menu/module/mpin/reset_mpin_page.dart';
import 'package:cis_menu/module/pengisi_modal/pengisi_modal_page.dart';
import 'package:cis_menu/module/laporan/laporan_data_petugas_page.dart';
import 'package:cis_menu/module/laporan/laporan_data_teller_page.dart';
import 'package:cis_menu/module/laporan/laporan_user_access_page.dart';
import 'package:cis_menu/module/rekon_transaksi/rekon_transaksi_page.dart';
import 'package:cis_menu/module/users_access/users_access_page.dart';
import 'package:cis_menu/module/setup/limit_transaksi/limit_transaksi_page.dart';
import 'package:cis_menu/module/setup/setup_transaksi/setup_transaksi_page.dart';
import 'package:cis_menu/module/buka_tutup_transaksi/buka_tutup_petugas_page.dart';
import 'package:cis_menu/module/buka_tutup_transaksi/buka_tutup_teller_page.dart';
import 'package:cis_menu/utils/colors.dart';
import 'package:cis_menu/utils/idle_logout_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  static const _pages = <int, Widget>{
    0:  DashboardPage(),
    1:  UsersAccessPage(),
    2:  KantorPage(),
    10: LimitTransaksiPage(),
    14: SetupTransaksiPage(),
    20: DataTellerPage(),
    21: DataPetugasPage(),
    30: GenerateMpinPage(),
    31: CetakMpinPage(),
    32: RegenerateMpinPage(),
    33: ResetMpinPage(),
    40: DataKartuPage(),
    41: UpdateStatusPage(),
    50: PengisianModalPage(),
    60: RekonTransaksiPage(),
    61: LaporanUserAccessPage(),
    62: LaporanDataTellerPage(),
    63: LaporanDataPetugasPage(),
    64: LaporanTransaksiPetugasPage(), // 🔥 TAMBAHKAN
    70: BukaTutupPetugasPage(),
    71: BukaTutupTellerPage(),
  };

  List<_MenuItem> _menuItems(MenuNotifier n) => [
        const _MenuItem('KANTOR', Icons.business, page: 2,
            menu: 'KANTOR', submenu: 'KANTOR'),
        const _MenuItem('USER ACCESS', Icons.person, page: 1,
            menu: 'USER ACCESS', submenu: 'USER ACCESS'),
        const _MenuItem('SETUP', Icons.settings, menu: 'SETUP', children: [
          _MenuItem('Limit Transaksi', Icons.payment, page: 10,
              menu: 'SETUP', submenu: 'LIMIT SETOR'),
          _MenuItem('Transaksi Collector', Icons.build, page: 14,
              menu: 'SETUP', submenu: 'TRANSAKSI COLLECTOR'),
        ]),
        const _MenuItem('DATA TELLER', Icons.account_box, page: 20,
            menu: 'DATA TELLER', submenu: 'DATA TELLER'),
        const _MenuItem('DATA PETUGAS', Icons.badge, page: 21,
            menu: 'DATA PETUGAS', submenu: 'DATA PETUGAS'),
        const _MenuItem('M-PIN PETUGAS', Icons.pin, menu: 'M-PIN', children: [
          _MenuItem('Generate M-PIN', Icons.qr_code, page: 30,
              menu: 'M-PIN', submenu: 'GENERATE M-PIN'),
          _MenuItem('Cetak M-PIN', Icons.print, page: 31,
              menu: 'M-PIN', submenu: 'CETAK M-PIN'),
          _MenuItem('Regenerate M-PIN', Icons.refresh, page: 32,
              menu: 'M-PIN', submenu: 'REGENERATE M-PIN'),
          _MenuItem('Reset M-PIN', Icons.lock_reset, page: 33,
              menu: 'M-PIN', submenu: 'RESET M-PIN'),
        ]),
        const _MenuItem('BUKA & TUTUP TRANSAKSI', Icons.dashboard,
            menu: 'BUKA & TUTUP TRANSAKSI', children: [
          _MenuItem('Petugas', Icons.person_search, page: 70,
              menu: 'BUKA & TUTUP TRANSAKSI', submenu: 'PETUGAS'),
          _MenuItem('Teller', Icons.account_balance, page: 71,
              menu: 'BUKA & TUTUP TRANSAKSI', submenu: 'TELLER'),
        ]),
        const _MenuItem('PENGISIAN MODAL', Icons.account_balance_wallet,
            page: 50, menu: 'PENGISIAN MODAL', submenu: 'PENGISIAN MODAL'),
        const _MenuItem('LAPORAN', Icons.history,
            menu: 'LAPORAN', children: [
          _MenuItem('User Access', Icons.manage_accounts, page: 61,
              menu: 'LAPORAN', submenu: 'USER ACCESS'),
          _MenuItem('Data Teller', Icons.account_box, page: 62,
              menu: 'LAPORAN', submenu: 'DATA TELLER'),
          _MenuItem('Data Petugas', Icons.badge, page: 63,
              menu: 'LAPORAN', submenu: 'DATA PETUGAS'),
          _MenuItem('Transaksi Petugas', Icons.receipt_long, page: 64, // 🔥 TAMBAHKAN
              menu: 'LAPORAN', submenu: 'TRANSAKSI PETUGAS'),
        ]),
      ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MenuNotifier(context: context),
      child: Consumer<MenuNotifier>(
        builder: (context, value, _) => IdleDetector(
          child: SafeArea(
            child: Scaffold(
              body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!value.isloading) _Sidebar(value: value, items: _menuItems(value)),
                Expanded(child: _pages[value.page] ?? const DashboardPage()),
              ],
            ),
          ),
        ),
      ),
    )
  );
  }
}

// ─── Data model menu ────────────────────────────────────────────────────────

class _MenuItem {
  final String title;
  final IconData icon;
  final int? page;
  final String? menu;
  final String? submenu;
  final List<_MenuItem>? children;

  const _MenuItem(this.title, this.icon,
      {this.page, this.menu, this.submenu, this.children});

  bool visible(MenuNotifier n) {
    if (menu == null) return true;
    // Grup parent: tampilkan jika setidaknya satu child visible
    if (children != null) {
      return children!.any((c) => c.visible(n));
    }
    // Menu leaf: cek akses submenu spesifik
    return n.hasAccess(menu!, submenu: submenu ?? menu!);
  }
}

// ─── Sidebar ────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final MenuNotifier value;
  final List<_MenuItem> items;

  const _Sidebar({required this.value, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: colorPrimary),
      child: ListView(
        children: [
          const SizedBox(height: 16),
          const Text(
            'CIS',
            style: TextStyle(
              fontFamily: "Arial Black",
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Collector Information System',
            style: TextStyle(fontSize: 11, color: Colors.white),
          ),
          if (value.users != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        value.users!.namaUsers ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '(${value.users!.usersId} - ${value.users!.bprId})',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: value.confirmDelete,
                  icon: const Icon(
                    Icons.power_settings_new,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: value.gantipassword,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Ganti Password',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const Divider(color: Colors.white24),
          ],
          const SizedBox(height: 8),
          ...items
              .where((e) => e.visible(value))
              .map((e) => _MenuTile(item: e, value: value)),
        ],
      ),
    );
  }
}

// ─── Menu tile (item level 1) ────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  final _MenuItem item;
  final MenuNotifier value;

  const _MenuTile({required this.item, required this.value});

  @override
  Widget build(BuildContext context) {
    final visibleChildren =
        item.children?.where((c) => c.visible(value)).toList();

    if (visibleChildren != null && visibleChildren.isNotEmpty) {
      return ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,
        title: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            children: [
              Icon(item.icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        children: visibleChildren
            .map((c) => _SubMenuTile(item: c, value: value))
            .toList(),
      );
    }

    final active = value.page == item.page;
    return InkWell(
      onTap: item.page == null ? null : () => value.gantipage(item.page!),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(item.icon,
                color: active ? colorPrimary : Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  color: active ? colorPrimary : Colors.white,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-menu tile (item level 2) ───────────────────────────────────────────

class _SubMenuTile extends StatelessWidget {
  final _MenuItem item;
  final MenuNotifier value;

  const _SubMenuTile({required this.item, required this.value});

  @override
  Widget build(BuildContext context) {
    final active = value.page == item.page;
    return InkWell(
      onTap: item.page == null ? null : () => value.gantipage(item.page!),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.only(left: 32, top: 2, bottom: 2),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(item.icon,
                color: active ? colorPrimary : Colors.white, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  color: active ? colorPrimary : Colors.white,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}