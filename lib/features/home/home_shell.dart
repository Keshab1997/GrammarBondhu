import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../home/home_screen.dart';
import '../chapters/chapter_list_screen.dart';
import '../rewards/rewards_screen.dart';
import '../profile/profile_screen.dart';

/// The tabbed home shell — Screen 6 plus Library, Rewards and Profile tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});

  static const routeName = '/home';

  final int initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          HomeScreen(),
          ChapterListScreen(),
          RewardsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primarySoft,
          labelTextStyle: WidgetStatePropertyAll(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined),
              selectedIcon: Icon(Icons.emoji_events_rounded),
              label: 'Rewards',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
