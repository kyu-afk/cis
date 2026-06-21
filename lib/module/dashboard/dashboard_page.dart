import 'package:cis_menu/module/dashboard/dashboard_notifier.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardNotifier(context: context),
      child: Consumer<DashboardNotifier>(
        builder: (context, value, child) => const SafeArea(
            child: Scaffold(
              backgroundColor: Color(0xffF3F5F4),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [],
          ),
        )),
      ),
    );
  }
}
