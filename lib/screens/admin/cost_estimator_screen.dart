import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/historical_project_model.dart';
import '../../state/estimator_provider.dart';

class CostEstimatorScreen extends ConsumerStatefulWidget {
  const CostEstimatorScreen({super.key});

  @override
  ConsumerState<CostEstimatorScreen> createState() => _CostEstimatorScreenState();
}

class _CostEstimatorScreenState extends ConsumerState<CostEstimatorScreen> {
  String _projectType = 'Survey';
  final _durationController = TextEditingController(text: '6');
  final _staffCountController = TextEditingController(text: '15');
  final _locationsController = TextEditingController(text: '20');
  final _respondentsController = TextEditingController(text: '5000');
  String _travelIntensity = 'High';
  final _proposedFeeController = TextEditingController(text: '2500000');

  EstimationResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculate());
  }

  @override
  void dispose() {
    _durationController.dispose();
    _staffCountController.dispose();
    _locationsController.dispose();
    _respondentsController.dispose();
    _proposedFeeController.dispose();
    super.dispose();
  }

  void _calculate() {
    final duration = int.tryParse(_durationController.text.trim()) ?? 6;
    final staff = int.tryParse(_staffCountController.text.trim()) ?? 15;
    final locations = int.tryParse(_locationsController.text.trim()) ?? 20;
    final respondents = int.tryParse(_respondentsController.text.trim()) ?? 5000;
    final fee = double.tryParse(_proposedFeeController.text.trim()) ?? 2500000.0;

    final res = ref.read(estimatorProvider.notifier).calculateEstimate(
          projectType: _projectType,
          durationMonths: duration,
          staffCount: staff,
          locationsCount: locations,
          respondentsCount: respondents,
          travelIntensity: _travelIntensity,
          proposedFee: fee,
        );

    setState(() => _result = res);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;


    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Historical Cost Estimator (PRD Section 22)', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Introductory Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withAlpha(50)),
            ),
            child: const Row(
              children: [
                Icon(Icons.psychology_rounded, color: AppColors.primary, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Estimate new project costs and pricing based on historical survey benchmarks, staff requirements, and field travel intensity.',
                    style: TextStyle(fontSize: 12, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Inputs Card (PRD Section 22)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Project Parameters', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _projectType,
                        decoration: const InputDecoration(labelText: 'Project Type'),
                        items: ['Survey', 'Feasibility', 'Impact Assessment', 'IT/Engineering', 'Advisory'].map((t) {
                          return DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)));
                        }).toList(),
                        onChanged: (v) {
                          setState(() => _projectType = v!);
                          _calculate();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Duration (Months)'),
                        onChanged: (_) => _calculate(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _staffCountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Field Staff Count'),
                        onChanged: (_) => _calculate(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _locationsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Districts / Locations'),
                        onChanged: (_) => _calculate(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _respondentsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Sample Size / Respondents'),
                        onChanged: (_) => _calculate(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _travelIntensity,
                        decoration: const InputDecoration(labelText: 'Travel Requirement'),
                        items: ['Low', 'Medium', 'High'].map((t) {
                          return DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)));
                        }).toList(),
                        onChanged: (v) {
                          setState(() => _travelIntensity = v!);
                          _calculate();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _proposedFeeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Proposed Contract Fee / Client Budget (৳)',
                    prefixText: '৳ ',
                  ),
                  onChanged: (_) => _calculate(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Output Cards (PRD Section 22)
          if (_result != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ESTIMATION RESULTS (PRD Section 22)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF38BDF8), letterSpacing: 1),
                  ),
                  const SizedBox(height: 14),
                  _buildResultRow('Estimated Direct Project Cost:', CurrencyFormatter.format(_result!.estimatedCost), Colors.white),
                  const Divider(color: Colors.white24, height: 16),
                  _buildResultRow('Recommended Contingency (8-12%):', CurrencyFormatter.format(_result!.recommendedContingency), const Color(0xFFFBBF24)),
                  const Divider(color: Colors.white24, height: 16),
                  _buildResultRow('Total Estimated Budget:', CurrencyFormatter.format(_result!.estimatedTotalBudget), Colors.white, isBold: true),
                  const Divider(color: Colors.white24, height: 16),
                  _buildResultRow(
                    'Estimated Profit at Proposed Fee:',
                    '${CurrencyFormatter.format(_result!.estimatedProfit)} (${_result!.estimatedProfitMargin.toStringAsFixed(1)}%)',
                    _result!.estimatedProfit >= 0 ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Historical Category Breakdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estimated Cost Distribution by Category', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  ..._result!.categoryEstimates.entries.map((e) {
                    final percent = _result!.estimatedTotalBudget > 0
                        ? (e.value / _result!.estimatedTotalBudget) * 100
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('${CurrencyFormatter.format(e.value, compact: true)} (${percent.toStringAsFixed(1)}%)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: (percent / 100).clamp(0.0, 1.0),
                            backgroundColor: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reference Benchmark Projects
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Benchmark Reference Projects Used:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
                  const SizedBox(height: 6),
                  ..._result!.referenceProjects.map((p) => Text('• $p', style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
