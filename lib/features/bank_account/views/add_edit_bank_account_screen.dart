import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/service/dialog_service.dart';
import '../controllers/bank_account_controller.dart';

class AddEditBankAccountScreen extends GetWidget<BankAccountController> {
  const AddEditBankAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = controller.editingAccount != null;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        title: Text(
          isEditing ? "Edit Account" : 'Add Account',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputLabel(theme, 'Bank Name'),
              _buildTextField(
                controller: controller.bankNameCtrl,
                theme: theme,
                isDark: isDark,
                hintText: "e.g., Bank of America",
                icon: Icons.account_balance,
                validator: (val) => val!.isEmpty ? "Required field" : null,
              ),
              const SizedBox(height: 20),
              _buildInputLabel(theme, 'Account Number'),
              _buildTextField(
                controller: controller.bankAccountNumberCtrl,
                keyboardType: TextInputType.number,
                theme: theme,
                isDark: isDark,
                hintText: 'Enter account number',
                icon: Icons.numbers,
                validator: (val) => val!.isEmpty ? "Required field" : null,
              ),
              const SizedBox(height: 20),

              _buildInputLabel(theme, 'Account Holder Name'),
              _buildTextField(
                controller: controller.holderNameCtrl,
                theme: theme,
                isDark: isDark,
                hintText: "Enter full name",
                icon: Icons.person_outline,
                validator: (val) => val!.isEmpty ? "Required field" : null,
              ),
              const SizedBox(height: 20),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputLabel(theme, 'Account Type'),
                        _buildDropdown(theme, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputLabel(theme, "Initial Balance"),
                        _buildTextField(
                          controller: controller.balanceCtrl,
                          theme: theme,
                          isDark: isDark,
                          hintText: '0.00',
                          icon: Icons.currency_rupee_sharp,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (val) {
                            if (val!.isEmpty) return "Required";
                            if (double.tryParse(val) == null) return "Invalid";
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    if (controller.formKey.currentState?.validate() == true) {
                      final bool? isConfirmed = await DialogService.showConfirmDialog(
                        title: isEditing ? "Confirm Update" : "Confirm Save",
                        description: isEditing 
                            ? "Are you sure you want to update this account?" 
                            : "Are you sure you want to save this account?",
                        confirmText: 'Confirm',
                      );
                      if (isConfirmed == true) {
                        if (isEditing) {
                          controller.updateBankAccount();
                        } else {
                          controller.addBankAccount();
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isEditing ? "Update Account" : "Save Account",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required ThemeData theme,
    required bool isDark,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        prefixIcon: Icon(
          icon,
          color: theme.colorScheme.primary.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1A1C35) : const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2A2D52) : Colors.transparent,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1),
        ),
      ),
    );
  }

  Widget _buildDropdown(ThemeData theme, bool isDark) {
    return Obx(
      () => DropdownButtonFormField<String>(
        initialValue: controller.selectedAccountType.value,
        dropdownColor: isDark ? const Color(0xFF1E213A) : Colors.white,
        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
        decoration: InputDecoration(
          filled: true,
          fillColor: isDark ? const Color(0xFF1A1C35) : const Color(0xFFF5F7FA),
          prefixIcon: Icon(
            Icons.category_outlined,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF2A2D52) : Colors.transparent,
              width: 1,
            ),
          ),
        ),
        items: controller.accountTypes.map((String type) {
          return DropdownMenuItem<String>(value: type, child: Text(type));
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            controller.selectedAccountType.value = newValue;
          }
        },
      ),
    );
  }
}
