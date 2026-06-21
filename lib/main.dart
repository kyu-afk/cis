import 'dart:io';

import 'package:cis_menu/config/template_bootstrap.dart';
import 'package:cis_menu/config/template_config.dart';
import 'package:cis_menu/module/auth/login_page.dart';
import 'package:cis_menu/module/menu/menu_page.dart';
import 'package:cis_menu/network/api_client.dart';
import 'package:cis_menu/utils/custom_scroll.dart';
import 'package:flutter/material.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await TemplateBootstrap.ensureSession();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // navigatorKey dipakai ApiClient untuk redirect ke /login
      // ketika backend mengembalikan rc = TOKEN_INVALID
      navigatorKey: ApiClient.navigatorKey,
      debugShowCheckedModeBanner: false,
      scrollBehavior: MyCustomScrollBehavior(),
      initialRoute: TemplateConfig.skipLogin ? '/menu' : '/login',
      routes: {
        '/login': (_) => const LoginPage(),
        '/menu':  (_) => const MenuPage(),
      },
    );
  }
}

