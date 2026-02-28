import 'package:flutter/material.dart';
import '/screens/blog/blog_feed_screen.dart';
import '/screens/profile/me_screen.dart';
import 'package:smart_chef/screens/health/nutrition_dashboard_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  final List<Widget> pages = [
    BlogFeedScreen(),
    const MeScreen(), //change this to your module - SHA
    const MeScreen(), //change this to your module - WK
    NutritionDashboardScreen(), //change this to your module - JX
    const MeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white, // Background of the bar
        selectedItemColor: const Color(0xFF00A676), // Your SmartChef Brand Green
        unselectedItemColor: Colors.grey, // Color for inactive items
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold), // Optional: make text bold when active
        showUnselectedLabels: true, // Optional: ensures text is always visible
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Feed', // Account + Blog
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Planner', // Meal Planner
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.delete_outline),
            label: 'Waste', // Food Waste
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Health', // Nutrition & Health
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}