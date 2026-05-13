import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../routes/app_routes.dart';
import '../../bank_account/controllers/bank_account_controller.dart';
import '../../bank_account/models/bank_account_model.dart';
import '../../cash_wallet/controller/cash_wallet_controller.dart';
import '../../navbar/widgets/navbar_scroll_listener.dart';
import '../../navbar/controller/navbar_controller.dart';
import '../../tags/controllers/tags_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/home_controller.dart';
import '../../../core/service/local_storage_service.dart';

class HomeScreen extends GetWidget<HomeController> {
  HomeScreen({super.key});

  final bankAccountController = Get.find<BankAccountController>();
  final cashWalletController = Get.find<CashWalletController>();
  final dashboardController = Get.find<DashboardController>();
  final navbarController = Get.find<NavbarController>();

  final _inrFmt = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
    locale: 'en_IN',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(
              () => Text(
                controller.greeting.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            Row(
              children: [
                Flexible(
                  child: Text(
                    LocalStorageService.instance.accountName.isNotEmpty
                        ? '${LocalStorageService.instance.accountName} 👋'
                        : 'User',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: NavbarScrollListener(
        child: RefreshIndicator(
          onRefresh: dashboardController.refreshDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBalanceCard(theme, isDark),
                const SizedBox(height: 24),
                _buildQuickActions(context, theme, isDark),
                const SizedBox(height: 32),

                // Bank Accounts Section
                Obx(
                  () => bankAccountController.bankAccounts.isNotEmpty
                      ? Column(
                          children: [
                            _buildSectionHeader(
                              theme,
                              'My Accounts',
                              'View All',
                              () => Get.toNamed(AppRoutes.bankAccountsScreen),
                            ),
                            const SizedBox(height: 16),
                            _buildBankAccountsList(
                              context,
                              theme,
                              isDark,
                              accounts: bankAccountController.bankAccounts
                                  .take(3)
                                  .toList(),
                            ),
                            const SizedBox(height: 32),
                          ],
                        )
                      : Center(child: _buildEmptyBankAccounts(theme)),
                ),

                // Cash Wallet Section
                _buildSectionHeader(
                  theme,
                  'Cash Wallet',
                  'Manage',
                  () => Get.toNamed(AppRoutes.cashWalletScreen),
                ),
                const SizedBox(height: 16),
                _buildCashWalletBalanceCard(theme, isDark),
                const SizedBox(height: 32),

                // Virtual Entries Section
                _buildSectionHeader(
                  theme,
                  'Virtual Entries',
                  'View All',
                  () => Get.toNamed(AppRoutes.virtualEntriesScreen),
                ),
                const SizedBox(height: 16),
                _buildVirtualEntriesCard(theme, isDark),
                const SizedBox(height: 32),

                // Recent Transactions Section
                _buildSectionHeader(
                  theme,
                  'Recent Transactions',
                  'View All',
                  () => navbarController.jumpToTransactions(),
                ),
                const SizedBox(height: 16),
                _buildRecentTransactions(theme, isDark),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Balance Card ──────────────────────────────────────────────────────────
  Widget _buildBalanceCard(ThemeData theme, bool isDark) {
    return Obx(() {
      final totalBalance = dashboardController.totalBalance.value;
      final income = dashboardController.totalIncome.value;
      final expenses = dashboardController.totalExpenses.value;

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF4A4E9E), const Color(0xFF2A2D52)]
                : [theme.colorScheme.primary, theme.colorScheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Total Balance',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Last updated indicator
                Obx(
                  () => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      dashboardController.lastUpdated.value.isNotEmpty
                          ? 'Updated ${dashboardController.lastUpdated.value}'
                          : '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            dashboardController.isLoading.value
                ? const SizedBox(
                    height: 42,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  )
                : Text(
                    _inrFmt.format(totalBalance),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildBalanceStatBox(
                    'Income',
                    _inrFmt.format(income),
                    Icons.download_rounded,
                    Colors.greenAccent,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.3),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  child: _buildBalanceStatBox(
                    'Expenses',
                    _inrFmt.format(expenses),
                    Icons.upload_rounded,
                    Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildBalanceStatBox(
    String title,
    String amount,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              Text(
                amount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Cash Wallet Card ──────────────────────────────────────────────────────
  Widget _buildCashWalletBalanceCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1C35) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D52) : const Color(0xFFE4E6FF),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: theme.colorScheme.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Cash',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Obx(
                  () => Text(
                    _inrFmt.format(dashboardController.cashBalance.value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.currency_rupee_sharp,
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Virtual Entries Card ──────────────────────────────────────────────────
  Widget _buildVirtualEntriesCard(ThemeData theme, bool isDark) {
    return Obx(() {
      final receivable = dashboardController.totalReceivable.value;
      final payable = dashboardController.totalPayable.value;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1C35) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2D52) : const Color(0xFFE4E6FF),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildVirtualEntryItem(
                theme,
                'To Receive',
                _inrFmt.format(receivable),
                Icons.arrow_downward_rounded,
                Colors.green,
              ),
            ),
            Container(
              width: 1,
              height: 60,
              color: isDark ? const Color(0xFF2A2D52) : const Color(0xFFE4E6FF),
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
            Expanded(
              child: _buildVirtualEntryItem(
                theme,
                'To Pay',
                _inrFmt.format(payable),
                Icons.arrow_upward_rounded,
                Colors.redAccent,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildVirtualEntryItem(
    ThemeData theme,
    String title,
    String amount,
    IconData icon,
    Color iconColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  // ─── Recent Transactions ───────────────────────────────────────────────────
  Widget _buildRecentTransactions(ThemeData theme, bool isDark) {
    return Obx(() {
      if (dashboardController.isLoading.value &&
          dashboardController.recentTransactions.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        );
      }

      final txns = dashboardController.recentTransactions;
      if (txns.isEmpty) {
        return _buildEmptyState(
          theme,
          Icons.receipt_long_outlined,
          'No transactions yet',
          'Import a bank statement to get started.',
        );
      }

      return Column(
        children: txns.map((tx) {
          final isCredit = tx.isCredit;
          final color = isCredit ? Colors.green : theme.colorScheme.error;
          final icon = isCredit
              ? Icons.arrow_downward_rounded
              : Icons.arrow_upward_rounded;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1C35) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2A2D52)
                    : const Color(0xFFE4E6FF),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Circular Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),

                // Title (Narration) + Tag Chip
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.narration,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Tag chip
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tx.tagName,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tx.formattedDate,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Amount & Account info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      tx.formattedAmount,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tx.lastFourDigits.isNotEmpty
                          ? '${tx.bankName} ••••${tx.lastFourDigits}'
                          : tx.bankName,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      overflow: TextOverflow.clip,
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      );
    });
  }

  // ─── Bank Accounts List ────────────────────────────────────────────────────
  Widget _buildBankAccountsList(
    BuildContext context,
    ThemeData theme,
    bool isDark, {
    required List<BankAccountModel> accounts,
  }) {
    // Dynamic width calculation to fit comfortably without forcing a massive width on smaller screens
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.75 > 280.0 ? 280.0 : screenWidth * 0.75;

    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        clipBehavior: Clip.none,
        separatorBuilder: (ctx, _) => const SizedBox(width: 16),
        itemBuilder: (ctx, index) {
          final acc = accounts[index];
          final colors = [
            Colors.deepPurpleAccent,
            Colors.redAccent,
            Colors.green,
            Colors.orange,
            Colors.blue,
          ];
          final logoColor = colors[acc.bankName.length % colors.length];
          final topBg = isDark
              ? const Color(0xFF2A2D52)
              : const Color(0xFFE4E6FF);
          final bottomBg = isDark ? const Color(0xFF1A1C35) : Colors.white;

          return GestureDetector(
            onTap: () => Get.toNamed(
              AppRoutes.transactionsScreen,
              arguments: {'encryptedAccountNumber': acc.encryptedAccountNumber},
            ),
            child: Container(
              width: cardWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    // ── Top half ──
                    Container(
                      color: topBg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: logoColor.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: logoColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        acc.bankName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: acc.isActive
                                            ? Colors.green.withValues(
                                                alpha: 0.1,
                                              )
                                            : Colors.grey.withValues(
                                                alpha: 0.1,
                                              ),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                          color: acc.isActive
                                              ? Colors.green.withValues(
                                                  alpha: 0.3,
                                                )
                                              : Colors.grey.withValues(
                                                  alpha: 0.3,
                                                ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        acc.isActive ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: acc.isActive
                                              ? Colors.green.shade700
                                              : Colors.grey.shade700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Obx(() {
                                  final key = acc.encryptedAccountNumber;
                                  final isVisible =
                                      bankAccountController
                                          .accountVisibility[key] ??
                                      false;
                                  final isRev = bankAccountController
                                      .isRevealing
                                      .contains(key);
                                  final display = isVisible
                                      ? bankAccountController
                                                .revealedNumbers[key] ??
                                            '****'
                                      : bankAccountController.maskedDisplay(
                                          acc.lastFourDigits,
                                        );

                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          display,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                      isRev
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              icon: Icon(
                                                isVisible
                                                    ? Icons.visibility_off
                                                    : Icons.visibility,
                                                size: 18,
                                              ),
                                              onPressed: () =>
                                                  bankAccountController
                                                      .toggleVisibility(key),
                                            ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Bottom half ──
                    Expanded(
                      child: Container(
                        color: bottomBg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    NumberFormat.currency(
                                      symbol: '₹',
                                      decimalDigits: 2,
                                      locale: 'en_IN',
                                    ).format(acc.currentBalance),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    acc.accountHolderName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Icon(
                                Icons.refresh_rounded,
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.6,
                                ),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Quick Actions ─────────────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext ctx, ThemeData theme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _buildActionBtn(
            ctx,
            theme,
            isDark,
            title: 'Import',
            icon: Icons.upload_file_rounded,
            onTap: () => Get.toNamed(AppRoutes.uploadFileScreen),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionBtn(
            ctx,
            theme,
            isDark,
            title: 'Account',
            icon: Icons.account_balance_rounded,
            onTap: () {
              bankAccountController.clearForm();
              Get.toNamed(AppRoutes.addEditBankAccountScreen);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionBtn(
            ctx,
            theme,
            isDark,
            title: 'Add Tags',
            icon: Icons.tag_rounded,
            onTap: () {
              final tagCtr = Get.find<TagsController>();
              tagCtr.clearCreateTagState();
              tagCtr.fetchBankAccouts();
              tagCtr.initCreateTag();
              Get.toNamed(AppRoutes.tagAddEdit);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionBtn(
            ctx,
            theme,
            isDark,
            title: 'More',
            icon: Icons.grid_view_rounded,
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn(
    BuildContext ctx,
    ThemeData theme,
    bool isDark, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E213A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(
    ThemeData theme,
    String title,
    String actionLabel,
    VoidCallback onTap,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onTap,
          child: Text(
            actionLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Empty States ──────────────────────────────────────────────────────────
  Widget _buildEmptyBankAccounts(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 32),
        Icon(
          Icons.account_balance_outlined,
          size: 48,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 12),
        Text(
          'No bank accounts found',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Add your first bank account to get started',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Get.toNamed(AppRoutes.addEditBankAccountScreen),
          child: const Text('Add Account'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
