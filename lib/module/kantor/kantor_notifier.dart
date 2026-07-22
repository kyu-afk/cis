// PATCH: Kantor disamakan dengan MEDFO — data bersumber dari HRIS (hr.medtrans.id),
// halaman ini murni read-only. Tambah/ubah/hapus kantor tidak lagi dilakukan dari
// aplikasi ini, melainkan lewat sistem HRIS.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/index.dart';
import '../../network/network.dart';
import '../../pref/pref.dart';
import '../../repository/users_access_repository.dart';

class KantorNotifier extends ChangeNotifier {
  final BuildContext context;

  KantorNotifier({required this.context}) {
    _init();
  }

  final GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

  bool isLoading = true;
  List<KantorModel> listResult = [];
  String? _bprId;
  String? _userId;

  Future<void> _init() async {
    final users = await Pref().getUsers();
    _bprId = users.bprId;
    _userId = users.usersId;
    await getKantor();
  }

  Future<void> getKantor() async {
    if (_bprId == null) return;
    isLoading = true;
    notifyListeners();
    try {
      final result = await UsersAccessRepository.getListKantor(
        url: NetworkURL.getListKantorAccess(),
        userId: _userId ?? '',
        bprId: _bprId!,
      );
      final raw = (result['kantor'] as List<dynamic>? ?? []);
      listResult = raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return KantorModel.fromJson(m);
      }).toList();
    } catch (e) {
      if (kDebugMode) print('ERROR getKantor (HRM): $e');
      listResult = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
