// widgets/navbar_scroll_listener.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/navbar_controller.dart';

class NavbarScrollListener extends StatelessWidget {
  final Widget child;

  const NavbarScrollListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final NavbarController controller = Get.find<NavbarController>();

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          // Only respond to vertical scrolling
          if (notification.metrics.axis == Axis.vertical) {
            controller.handleScrollUpdate(
              notification.metrics.pixels,
              pixelsDelta: notification.scrollDelta,
            );
          }
        }
        // Return false to allow other listeners to receive the notification
        return false;
      },
      child: child,
    );
  }
}
