# CMS IBPR — Template Flutter

Proyek ini adalah **template** untuk membangun CMS (login, user access, kantor, dan modul lain). Saat dijalankan, aplikasi **tidak meminta login** — sesi demo diisi otomatis.

## Menjalankan

```bash
flutter pub get
flutter run -d chrome
```

## Mode template vs produksi

Edit `lib/config/template_config.dart`:

| Flag | Efek |
|------|------|
| `skipLogin = true` (default) | Langsung ke menu, user & akses demo |
| `skipLogin = false` | Halaman login wajib (`lib/module/auth/`) |

## Modul yang disertakan

- **Login** — `lib/module/auth/` (dipakai saat `skipLogin = false`)
- **User Access** — `lib/module/users_access/`
- **Kantor** — `lib/module/kantor/`
- **Dashboard** — placeholder kosong di `lib/module/dashboard/`

## Menambah modul baru

1. Buat folder di `lib/module/<nama>/`
2. Tambah entri akses di `TemplateConfig.defaultAkses` (untuk development)
3. Daftarkan menu di `lib/module/menu/menu_page.dart`
4. Tambah endpoint di `lib/network/network.dart` bila perlu

## URL API

Override base URL Web Service (login CMS user):

```bash
flutter run --dart-define=WS_BASE_URL=http://localhost:4002
```

## File yang sengaja tidak di-commit

`build/`, `.dart_tool/`, `*.log` — lihat `.gitignore`.
