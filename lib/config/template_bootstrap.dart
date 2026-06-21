import 'dart:convert';

import 'package:cis_menu/config/template_config.dart';
import 'package:cis_menu/models/index.dart';
import 'package:cis_menu/pref/pref.dart';

/// Mengisi sesi lokal untuk mode template (tanpa panggilan API login).
class TemplateBootstrap {
  static Future<void> ensureSession() async {
    if (!TemplateConfig.skipLogin) return;

    final users = await Pref().getUsers();
    final fasilitasJson = await Pref().getFasilitas();
    final hasUser = (users.usersId ?? '').trim().isNotEmpty;
    final hasAkses = fasilitasJson.trim().isNotEmpty && fasilitasJson != '[]';

    if (hasUser && hasAkses) return;

    await seedSession();
  }

  static Future<void> seedSession() async {
    const user = UsersModel(
      bprId: TemplateConfig.bprId,
      usersId: TemplateConfig.usersId,
      namaUsers: TemplateConfig.namaUsers,
      kodeKantor: TemplateConfig.kodeKantor,
      namaKantor: TemplateConfig.namaKantor,
    );

    await Pref().simpan(user);
    await Pref().setFasilitas(jsonEncode(TemplateConfig.defaultAkses));
  }
}
