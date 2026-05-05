// views/navbar_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import '../../home/views/home_screen.dart';
import '../../profile/views/profile_screen.dart';
import '../../tags/views/tags_screen.dart';
import '../../../core/service/dialog_service.dart';
import '../../transactions/views/all_transactions_screen.dart';
import '../controller/navbar_controller.dart';

class NavbarScreen extends GetWidget<NavbarController> {
  const NavbarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          if (controller.tabController.index != 0) {
            controller.backToHome();
          } else if (controller.tabController.index == 0) {
            await DialogService.showWarningDialog(
              title: "Exit Application",
              description: "Are you sure you want to exit the application?",
              onConfirm: () {
                SystemNavigator.pop();
              },
            );
          }
        }
      },
      child: PersistentTabView(
        controller: controller.tabController,
        navBarOverlap: const NavBarOverlap.full(),
        handleAndroidBackButtonPress: false,
        tabs: [
          PersistentTabConfig(
            screen: HomeScreen(),
            item: ItemConfig(
              icon: const Icon(Icons.space_dashboard_rounded),
              inactiveIcon: const Icon(Icons.space_dashboard_outlined),
              title: "Home",
            ),
          ),
          PersistentTabConfig(
            screen: TagsScreen(),
            item: ItemConfig(
              icon: const Icon(Icons.local_offer),
              inactiveIcon: const Icon(Icons.local_offer_outlined),
              title: "Tags",
            ),
          ),
          PersistentTabConfig(
            screen: AllTransactionsScreen(),
            item: ItemConfig(
              icon: const Icon(Icons.receipt_long_rounded),
              inactiveIcon: const Icon(Icons.receipt_long_outlined),
              title: 'Transactions',
            ),
          ),

          PersistentTabConfig(
            screen: const ProfileScreen(),
            item: ItemConfig(
              icon: const Icon(Icons.person_rounded),
              inactiveIcon: const Icon(Icons.person_outline_rounded),
              title: "Profile",
            ),
          ),
        ],
        navBarBuilder: (navBarConfig) =>
            _AnimatedNavBar(navBarConfig: navBarConfig, controller: controller),
      ),
    );
  }
}

/// Wraps the navbar with animation for hide/show effect
class _AnimatedNavBar extends StatelessWidget {
  final NavBarConfig navBarConfig;
  final NavbarController controller;

  const _AnimatedNavBar({required this.navBarConfig, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AnimatedSlide(
        offset: Offset(0, controller.isNavbarVisible.value ? 0 : 1),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: CustomNavBar(navBarConfig: navBarConfig),
      ),
    );
  }
}

class CustomNavBar extends StatelessWidget {
  final NavBarConfig navBarConfig;

  const CustomNavBar({super.key, required this.navBarConfig});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E213A) : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2D52) : const Color(0xFFE4E6FF),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: navBarConfig.items.map((item) {
            int index = navBarConfig.items.indexOf(item);
            bool isSelected = navBarConfig.selectedIndex == index;
            return GestureDetector(
              onTap: () => navBarConfig.onItemSelected(index),
              behavior: HitTestBehavior.opaque,
              child: _buildItem(context, item, isSelected),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, ItemConfig item, bool isSelected) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: isSelected ? 14 : 10,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTheme(
            data: IconThemeData(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              size: 24,
            ),
            child: isSelected ? item.icon : item.inactiveIcon,
          ),
          if (isSelected && item.title != null) ...[
            const SizedBox(width: 8),
            Text(
              item.title!,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
