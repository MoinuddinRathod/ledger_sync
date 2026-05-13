import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/service/dialog_service.dart';
import '../../../routes/app_routes.dart';
import '../controllers/bank_account_controller.dart';
import '../models/bank_account_model.dart';

class BankAccountsScreen extends GetWidget<BankAccountController> {
  const BankAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller if not already done in bindings
    Get.put(BankAccountController());

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormatter = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 2,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        title: Text(
          'My Accounts',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        onPressed: () {
          controller.initForm(null); // Null means Add mode
          Get.toNamed(
            AppRoutes.addEditBankAccountScreen,
            arguments: {"accountId": null},
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
      body: Obx(() {
        if (controller.bankAccounts.isEmpty) {
          return _buildEmptyState(theme);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          itemCount: controller.bankAccounts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final account = controller.bankAccounts[index];
            return _buildAccountCard(
              context,
              theme,
              isDark,
              account,
              currencyFormatter,
            );
          },
        );
      }),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    BankAccountModel account,
    NumberFormat formatter,
  ) {
    final colors = [
      Colors.deepPurpleAccent,
      Colors.redAccent,
      Colors.green,
      Colors.orange,
      Colors.blue,
    ];
    final logoColor = colors[account.bankName.length % colors.length];

    final cardBg = isDark ? const Color(0xFF1E213A) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2D325A) : const Color(0xFFEFEFFF);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Get.toNamed(
                AppRoutes.transactionsScreen,
                arguments: {
                  'encryptedAccountNumber': account.encryptedAccountNumber,
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Top Section: Logo, Bank Info, Switch ---
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              logoColor,
                              logoColor.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: logoColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.bankName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              account.accountType,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Reduced size Switch
                      Transform.scale(
                        scale: 0.75,
                        child: Obx(
                          () => Switch(
                            value: account.isActive,
                            onChanged: controller.isLoadingToggle.value
                                ? null
                                : (value) {
                                    controller.toggleAccountActive(account);
                                  },
                            activeColor: Colors.green.shade600,
                            activeTrackColor: Colors.green.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- Middle Section: Account Number Box ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF252945)
                          : const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.credit_card_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Obx(() {
                            final encryptedKey = account.encryptedAccountNumber;
                            final isVisible =
                                controller.accountVisibility[encryptedKey] ??
                                false;
                            final isLoading = controller.isRevealing.contains(
                              encryptedKey,
                            );

                            String displayText = isVisible
                                ? controller.revealedNumbers[encryptedKey] ??
                                    '****'
                                : controller.maskedDisplay(
                                    account.lastFourDigits,
                                  );

                            return Text(
                              displayText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: theme.colorScheme.onSurface,
                              ),
                            );
                          }),
                        ),
                        Obx(() {
                          final encryptedKey = account.encryptedAccountNumber;
                          final isVisible =
                              controller.accountVisibility[encryptedKey] ??
                              false;
                          final isLoading = controller.isRevealing.contains(
                            encryptedKey,
                          );

                          return isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : GestureDetector(
                                  onTap: () => controller.toggleVisibility(
                                    encryptedKey,
                                  ),
                                  child: Icon(
                                    isVisible
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Bottom Section: Balance and Actions ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Balance',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatter.format(account.currentBalance),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              account.accountHolderName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.3,
                                ),
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          // Edit Button
                          _buildCardActionBtn(
                            icon: Icons.edit_rounded,
                            color: Colors.blue,
                            onTap: () {
                              controller.initForm(account);
                              Get.toNamed(
                                AppRoutes.addEditBankAccountScreen,
                                arguments: {
                                  "accountId": account.encryptedAccountNumber,
                                },
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          // Delete Button
                          _buildCardActionBtn(
                            icon: Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            onTap: controller.isLoadingDelete.value
                                ? () {}
                                : () async {
                                    final bool? confirmed =
                                        await DialogService.showWarningDialog(
                                      title: 'Permanently Delete?',
                                      description:
                                          'Delete ${account.bankName} and all its data?',
                                      confirmText: 'Delete',
                                      onConfirm: () => Get.back(result: true),
                                    );

                                    if (confirmed == true) {
                                      controller.permanentlyDeleteAccount(
                                        account,
                                      );
                                    }
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardActionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No Accounts Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your bank accounts to track\nyour balances easily.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
