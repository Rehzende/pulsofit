import 'package:mobile_app/screens/ai_workout_suggestion_screen.dart';
import 'trainer/agent_chat_screen.dart';
import '../services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import 'home_screen.dart';
import 'workouts_screen.dart';

import 'trainer_home_screen.dart';
import 'coaches_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

import 'menu_screen.dart';
import 'notifications_screen.dart';
import 'chat_list_screen.dart';
import '../widgets/chat_icon.dart';

import 'trainer/trainer_students_screen.dart';
import 'trainer/trainer_workouts_screen.dart';
import 'onboarding_quiz_screen.dart';
import 'trainer_setup_wizard_screen.dart';
import 'profile_setup_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}


class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      // Refresh user details to ensure role and other data are up-to-date
      await auth.fetchUserDetails().catchError((_) {
        debugPrint('Failed to refresh user details on app startup');
      });

      _checkOnboarding();
      _fetchUnreadCount();

      try {
        NotificationService.initialize(auth.dio);
      } catch (e) {
        debugPrint('Failed to initialize NotificationService: $e');
      }
    });
  }

  Future<void> _fetchUnreadCount() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final resp = await auth.dio.get('${AppConstants.baseUrl}/notifications/unread-count');
      if (mounted) {
        setState(() => _unreadCount = (resp.data['unread_count'] as int?) ?? 0);
      }
    } catch (_) {}
  }

  void _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    _fetchUnreadCount(); // refresh badge after returning
  }

  void _checkOnboarding() {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (auth.fullName == null || auth.fullName!.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
      ).then((_) => _checkOnboarding());
      return;
    }

    if (auth.isStudent && !auth.anamnesisCompleted && !auth.anamnesisSkipped) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingQuizScreen()),
      ).then((_) => _checkOnboarding()); // Recursively check after dialog closes
    } else if (auth.isTrainer && (auth.trainerBrandName == null || auth.trainerBrandName!.isEmpty)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TrainerSetupWizardScreen()),
      ).then((_) => _checkOnboarding()); // Recursively check after dialog closes
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    final List<Widget> screens = [];
    final List<_NavItem> items = [];

    if (authProvider.isTrainer) {
      screens.addAll([
        TrainerHomeScreen(unreadCount: _unreadCount, onNotificationTap: _openNotifications),
        const TrainerWorkoutsScreen(),
        const AgentChatScreen(),
        const ChatListScreen(),
        const TrainerStudentsScreen(),
        const MenuScreen(),
      ]);

      items.addAll([
        _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Início'),
        _NavItem(icon: Icons.fitness_center_outlined, activeIcon: Icons.fitness_center_rounded, label: 'Treinos'),
        _NavItem(icon: Icons.bolt_outlined, activeIcon: Icons.bolt_rounded, label: 'Agente'),
        _NavItem(
          customIcon: ChatIcon(isActive: false, size: 20),
          customActiveIcon: ChatIcon(isActive: true, size: 20),
          label: 'Chat',
        ),
        _NavItem(icon: Icons.people_outline, activeIcon: Icons.people_rounded, label: 'Alunos'),
        _NavItem(icon: Icons.menu_rounded, activeIcon: Icons.menu_rounded, label: 'Menu'),
      ]);
    } else {
      screens.addAll([
        HomeScreen(unreadCount: _unreadCount, onNotificationTap: _openNotifications),
        const WorkoutsScreen(),
        const ChatListScreen(),
        const CoachesScreen(),
        const MenuScreen(),
      ]);

      items.addAll([
        _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Início'),
        _NavItem(icon: Icons.fitness_center_outlined, activeIcon: Icons.fitness_center_rounded, label: 'Treinos'),
        _NavItem(
          customIcon: ChatIcon(isActive: false, size: 20),
          customActiveIcon: ChatIcon(isActive: true, size: 20),
          label: 'Chat',
        ),
        _NavItem(icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded, label: 'Explorar'),
        _NavItem(icon: Icons.menu_rounded, activeIcon: Icons.menu_rounded, label: 'Menu'),
      ]);
    }

    if (_selectedIndex >= screens.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: _PulsoBottomNav(
        items: items,
        selectedIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// ============================================================
// Custom PULSO Bottom Navigation Bar
// ============================================================

class _NavItem {
  final IconData? icon;
  final IconData? activeIcon;
  final Widget? customIcon;
  final Widget? customActiveIcon;
  final String label;

  const _NavItem({
    this.icon,
    this.activeIcon,
    this.customIcon,
    this.customActiveIcon,
    required this.label,
  });
}

class _PulsoBottomNav extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _PulsoBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(AppConstants.cardDark),
        border: Border(
          top: BorderSide(
            color: Color(AppConstants.borderColor),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isActive = index == selectedIndex;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Active indicator line
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        width: isActive ? 28 : 0,
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: isActive
                              ? const LinearGradient(
                                  colors: [
                                    Color(AppConstants.neonAccent),
                                    Color(0xFFA855F7),
                                  ],
                                )
                              : null,
                        ),
                      ),

                      // Icon
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(6),
                        decoration: isActive
                            ? BoxDecoration(
                                color: const Color(AppConstants.neonAccent).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              )
                            : null,
                        child: item.customIcon != null
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: isActive && item.customActiveIcon != null
                                    ? item.customActiveIcon!
                                    : item.customIcon!,
                              )
                            : Icon(
                                isActive ? (item.activeIcon ?? item.icon) : item.icon,
                                size: 22,
                                color: isActive
                                    ? const Color(AppConstants.neonAccent)
                                    : const Color(AppConstants.textSecondary),
                              ),
                      ),

                      const SizedBox(height: 2),

                      // Label
                      Text(
                        item.label,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                          color: isActive
                              ? const Color(AppConstants.neonAccent)
                              : const Color(AppConstants.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
