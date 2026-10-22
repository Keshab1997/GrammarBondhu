import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../home/home_screen.dart';
import '../chapters/chapter_list_screen.dart';
import '../rewards/rewards_screen.dart';
import '../profile/profile_screen.dart';

/// The tabbed home shell — Screen 6 plus Library, Rewards and Profile tabs.
/// Floating glassy bottom navigation with pill indicator for the selected tab.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});

  static const routeName = '/home';

  final int initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _tab = widget.initialTab;

  static const _destinations = [
    (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home'),
    (
      icon: Icons.menu_book_outlined,
      active: Icons.menu_book_rounded,
      label: 'Library'
    ),
    (
      icon: Icons.emoji_events_outlined,
      active: Icons.emoji_events_rounded,
      label: 'Rewards'
    ),
    (
      icon: Icons.person_outline_rounded,
      active: Icons.person_rounded,
      label: 'Profile'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      // A soft sky wash behind the dashboard: the flat #F1F5FB canvas read as
      // "unfinished" next to the gradient hero card and the splash screen.
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE4EEFE),
              Color(0xFFF1F5FB),
              Color(0xFFF1F5FB),
            ],
            stops: [0.0, 0.35, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: IndexedStack(
          index: _tab,
          children: const [
            HomeScreen(),
            ChapterListScreen(),
            RewardsScreen(),
            ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < _destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _destinations[i].icon,
                    activeIcon: _destinations[i].active,
                    label: _destinations[i].label,
                    selected: _tab == i,
                    onTap: () => setState(() => _tab = i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        // The bar has a fixed height, so a label that wraps — narrow phones,
        // long labels, a raised system text scale — used to overflow the item
        // by a dozen pixels. scaleDown keeps the lockup intact inside it.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? activeIcon : icon,
                color: selected ? Colors.white : AppColors.textMuted,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
