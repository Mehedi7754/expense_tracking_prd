import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/notification_banner.dart';
import '../../state/settings_provider.dart';

class CompanySetupScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const CompanySetupScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<CompanySetupScreen> createState() => _CompanySetupScreenState();
}

class _CompanySetupScreenState extends ConsumerState<CompanySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _selectedCurrency;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  void _initFields(SettingsState settings) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = settings.companyName;
    _selectedCurrency = settings.baseCurrency;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 500));

    ref.read(settingsProvider.notifier).updateCompanyProfile(
          name: _nameController.text.trim(),
          baseCurrency: _selectedCurrency,
        );

    if (mounted) {
      setState(() => _isSaving = false);
      NotificationBanner.showSuccess(context, 'Company profile & base currency updated.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    _initFields(settings);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('Company Setup & Profile'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo Section (PRD Section 4.6)
                Text('Corporate Logo & Branding', style: AppTextStyles.titleSmall),
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppColors.getSurface(context),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.getBorder(context), width: 1.5),
                          boxShadow: (Theme.of(context).brightness == Brightness.dark) ? [] : AppColors.cardShadow,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.business_rounded,
                            size: 44,
                            color: AppColors.getPrimary(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text('Upload New Logo'),
                        onPressed: () {
                          NotificationBanner.showSuccess(context, 'Logo asset selected and uploaded.');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Company Name (PRD Section 4.6)
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Company Legal Name *',
                    hintText: 'e.g. Acme Global Enterprises Inc.',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Company name required' : null,
                ),
                const SizedBox(height: 18),

                // Base Currency (PRD Section 4.6)
                DropdownButtonFormField<String>(
                  value: _selectedCurrency,
                  decoration: const InputDecoration(
                    labelText: 'Base Reporting Currency *',
                    helperText: 'Used as standard baseline for company-wide budgets and rollups.',
                  ),
                  items: AppConstants.supportedCurrencies.map((curr) {
                    final symbol = AppConstants.currencySymbols[curr] ?? '';
                    return DropdownMenuItem<String>(
                      value: curr,
                      child: Text('$curr ($symbol)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCurrency = val);
                  },
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Company Settings'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
