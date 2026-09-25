import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/client_model.dart';
import '../../models/project_model.dart';
import '../../state/client_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';

class ClientAnalysisScreen extends ConsumerStatefulWidget {
  const ClientAnalysisScreen({super.key});

  @override
  ConsumerState<ClientAnalysisScreen> createState() => _ClientAnalysisScreenState();
}

class _ClientAnalysisScreenState extends ConsumerState<ClientAnalysisScreen> {
  ClientModel? _selectedClient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final clients = ref.watch(clientProvider);
    final projects = ref.watch(projectProvider);
    final expenses = ref.watch(expenseProvider);

    if (_selectedClient == null && clients.isNotEmpty) {
      _selectedClient = clients.first;
    }

    // Filter projects for selected client (Fix Pillar 4: Exact client ID / name match to prevent cross-client contamination)
    final clientProjects = _selectedClient != null
        ? projects.where((p) => p.clientId == _selectedClient!.id || p.client.trim().toLowerCase() == _selectedClient!.name.trim().toLowerCase()).toList()
        : <ProjectModel>[];

    // Compute Client-Level Metrics (PRD Section 21)
    final totalContracts = clientProjects.fold<double>(0.0, (sum, p) => sum + p.grossProjectValue);
    final totalRevenue = clientProjects.fold<double>(0.0, (sum, p) => sum + p.amountReceived);
    final totalReceivables = clientProjects.fold<double>(0.0, (sum, p) => sum + p.amountReceivable);

    double totalCostIncurred = 0.0;
    for (final p in clientProjects) {
      final pExp = expenses.where((e) => e.projectId == p.id);
      final direct = pExp.fold<double>(0.0, (sum, e) => sum + e.amount);
      totalCostIncurred += (direct * (1 + p.officeBenefitRate));
    }

    final totalProfit = totalContracts - totalCostIncurred;
    final averageProfitMargin = totalContracts > 0 ? (totalProfit / totalContracts) * 100 : 0.0;
    final completedProjects = clientProjects.where((p) => p.status == ProjectStatus.completed).length;
    final ongoingProjects = clientProjects.where((p) => p.status == ProjectStatus.ongoing).length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Client-Level Analysis (PRD Section 21)', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(16),
        children: [
          // Client Dropdown Selector
          DropdownButtonFormField<ClientModel>(
            value: _selectedClient,
            decoration: const InputDecoration(
              labelText: 'Select Client Organization',
              prefixIcon: Icon(Icons.corporate_fare_rounded),
            ),
            items: clients.map((c) {
              return DropdownMenuItem(value: c, child: Text(c.name, overflow: TextOverflow.ellipsis));
            }).toList(),
            onChanged: (c) => setState(() => _selectedClient = c),
          ),
          const SizedBox(height: 16),

          if (_selectedClient != null) ...[
            // Client Overview Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_selectedClient!.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _selectedClient!.clientType.displayName,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Contact: ${_selectedClient!.contactPerson}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('Email: ${_selectedClient!.email} • ${_selectedClient!.phone}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (_selectedClient!.notes != null) ...[
                    const SizedBox(height: 6),
                    Text(_selectedClient!.notes!, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Financial Summary Metrics Grid (PRD Section 21)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildMetricTile('Total Contracts', CurrencyFormatter.format(totalContracts, compact: true), Colors.white),
                      _buildMetricTile('Total Revenue', CurrencyFormatter.format(totalRevenue, compact: true), const Color(0xFF38BDF8)),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  Row(
                    children: [
                      _buildMetricTile('Total Cost (inc. OB)', CurrencyFormatter.format(totalCostIncurred, compact: true), const Color(0xFFFBBF24)),
                      _buildMetricTile(
                        'Total Profit',
                        '${CurrencyFormatter.format(totalProfit, compact: true)} (${averageProfitMargin.toStringAsFixed(1)}%)',
                        totalProfit >= 0 ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  Row(
                    children: [
                      _buildMetricTile('Receivables', CurrencyFormatter.format(totalReceivables, compact: true), const Color(0xFFF87171)),
                      _buildMetricTile('Projects Breakdown', '$ongoingProjects Ongoing • $completedProjects Completed', Colors.white70),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Projects List for this Client
            Text(
              'Client Projects Portfolio (${clientProjects.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),

            if (clientProjects.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('No projects recorded for this client.')),
              )
            else
              ...clientProjects.map((p) {
                final pExp = expenses.where((e) => e.projectId == p.id);
                final cost = pExp.fold<double>(0.0, (sum, e) => sum + e.amount) * (1 + p.officeBenefitRate);
                final profit = p.grossProjectValue - (cost + p.estimatedRemainingCost);
                final margin = p.grossProjectValue > 0 ? (profit / p.grossProjectValue) * 100 : 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: Text('${p.projectId} • Contract: ${CurrencyFormatter.format(p.grossProjectValue, compact: true)}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(profit, compact: true),
                          style: TextStyle(fontWeight: FontWeight.w800, color: profit >= 0 ? AppColors.success : AppColors.error),
                        ),
                        Text('Margin: ${margin.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    onTap: () => context.push(RoutePaths.projectDetail(p.id)),
                  ),
                );
              }),
            ],
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
