import 'package:get/get.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

class NavbarController extends GetxController {
  final PersistentTabController tabController = PersistentTabController();

  // Navbar visibility for scroll-based hide/show
  final RxBool isNavbarVisible = true.obs;
  double _lastScrollOffset = 0.0;
  double _accumulatedDelta = 0.0;

  // Thresholds (pixels) - adjust these for sensitivity
  static const double hideThreshold = 10.0;
  static const double showThreshold = 10.0;

  @override
  void onInit() {
    super.onInit();
    tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    resetScrollTracking();
  }

  /// Called when scroll update is detected from any screen
  void handleScrollUpdate(double currentOffset, {double? pixelsDelta}) {
    // Always show navbar when at the top
    if (currentOffset <= 0) {
      showNavbar();
      return;
    }

    final delta = pixelsDelta ?? (currentOffset - _lastScrollOffset);
    _accumulatedDelta += delta;

    // Hide when scrolling down enough
    if (_accumulatedDelta > hideThreshold && isNavbarVisible.value) {
      hideNavbar();
    }
    // Show when scrolling up enough
    else if (_accumulatedDelta < -showThreshold && !isNavbarVisible.value) {
      showNavbar();
    }

    _lastScrollOffset = currentOffset;
  }

  void hideNavbar() {
    if (isNavbarVisible.value) {
      isNavbarVisible.value = false;
    }
    _accumulatedDelta = 0;
  }

  void showNavbar() {
    if (!isNavbarVisible.value) {
      isNavbarVisible.value = true;
    }
    _accumulatedDelta = 0;
  }

  void resetScrollTracking() {
    _lastScrollOffset = 0;
    _accumulatedDelta = 0;
    showNavbar();
  }

  void backToHome() {
    tabController.jumpToTab(0);
    resetScrollTracking();
  }

  void jumpToTransactions() {
    tabController.jumpToTab(2);
    resetScrollTracking();
  }
}
