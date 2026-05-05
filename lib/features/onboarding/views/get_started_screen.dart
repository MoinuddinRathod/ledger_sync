import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/service/local_storage_service.dart';
import '../../../routes/app_routes.dart';

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              
              // App Logo/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF4A4E9E), const Color(0xFF2A2D52)]
                        : [colorScheme.primary, colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              
              const Spacer(flex: 1),
              
              // App Title
              Text(
                'Ledger Sync',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Benefits/Subtitle
              Text(
                'Track your expenses and income effortlessly.\nSimple accounting for everyone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Feature highlights
              _buildFeatureItem(
                icon: Icons.speed_rounded,
                title: 'Quick Entry',
                description: 'Log transactions in seconds',
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                icon: Icons.security_rounded,
                title: 'Secure & Private',
                description: 'Your data stays on your device',
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                icon: Icons.pie_chart_outline_rounded,
                title: 'Smart Insights',
                description: 'Understand your spending',
                colorScheme: colorScheme,
              ),
              
              const Spacer(flex: 2),
              
              // Get Started Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // Mark as first-time user completed onboarding
                    LocalStorageService.instance.hasCompletedOnboarding = true;
                    Get.offAllNamed(AppRoutes.masterAccountSetupScreen);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Skip/Login option for returning users who might have data
              TextButton(
                onPressed: () {
                  Get.offAllNamed(AppRoutes.masterAccountSetupScreen);
                },
                child: Text(
                  'Already have an account? Sign In',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 14,
                  ),
                ),
              ),
              
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
