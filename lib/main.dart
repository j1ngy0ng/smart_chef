import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_chef/screens/login/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://onpgamhynuwavemaskqy.supabase.co',
    anonKey: 'sb_publishable_EDvi6-MQTfeM9NWQvVZDXg_kIhcDpCu',
  );

  runApp(const SmartChefApp());
}

final supabase = Supabase.instance.client;

class SmartChefApp extends StatelessWidget {
  const SmartChefApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'SmartChef',
      theme: ThemeData(
        primaryColor: const Color(0xFF4CAF50),
        colorScheme: ColorScheme.fromSwatch()
            .copyWith(secondary: const Color(0xFFFF9800)),
      ),
      home: const LoginScreen(),
    );
  }
}
