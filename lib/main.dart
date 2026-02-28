import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:get/get_navigation/src/routes/get_route.dart';
import 'package:smart_chef/screens/blog/blog_feed_screen.dart';
import 'package:smart_chef/screens/dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_chef/screens/login/login_screen.dart';
import 'package:smart_chef/screens/health/nutrition_dashboard_screen.dart';

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
      // 1. Define the initial route (where the app starts)
      initialRoute: '/login',

      // 2. Map the names to the actual Screen widgets
      getPages: [
        GetPage(
          name: '/login',
          page: () => const LoginScreen(),
        ),
        // Make sure to add your Main/Home screen here too!
        GetPage(
          name: '/home',
           page: () => const DashboardScreen(),
         ),
        GetPage(
          name: '/nutrition',
          page: () => const NutritionDashboardScreen(),
        ),
      ],
    );
  }
}
