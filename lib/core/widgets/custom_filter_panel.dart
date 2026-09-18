import 'package:flutter/material.dart';
import '../../models/expense_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class FilterCriteria {
  final String? projectId;
  final String? categoryId;
  final String? employeeId;
  final ExpenseStatus? status;
  final DateTimeRange? dateRange;
  final double? minAmount;
  final double? maxAmount;

  const FilterCriteria({
    this.projectId,
    this.categoryId,
    this.employeeId,
    this.status,
    this.dateRange,
    this.minAmount,
    this.maxAmount,
  });

  bool get isActive =>
      projectId != null ||
      categoryId != null ||
      employeeId != null ||
      status != null ||
      dateRange != null ||
      minAmount != null ||
      maxAmount != null;

  FilterCriteria copyWith({
    String? projectId,
    String? categoryId,
    String? employeeId,
    ExpenseStatus? status,
    DateTimeRange? dateRange,
    double? minAmount,
    double? maxAmount,
    bool clearProject = false,
    bool clearCategory = false,
    bool clearEmployee = false,
    bool clearStatus = false,
    bool clearDateRange = false,
  }) {
    return FilterCriteria(
      projectId: clearProject ? null : (projectId ?? this.projectId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      employeeId: clearEmployee ? null : (employeeId ?? this.employeeId),
      status: clearStatus ? null : (status ?? this.status),
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
    );
  }
}

class CustomFilterPanel extends StatefulWidget {
  final FilterCriteria initialCriteria;
  final List<Map<String, String>> projects;
  final List<Map<String, String>> categories;
  final List<Map<String, String>> employees;
  final bool showEmployeeFilter;
  final bool showStatusFilter;
  final bool showAmountRange;
  final ValueChanged<FilterCriteria> onApply;

  const CustomFilterPanel({
    super.key,
    required this.initialCriteria,
    required this.projects,
    required this.categories,
    this.employees = const [],
    this.showEmployeeFilter = false,
    this.showStatusFilter = true,
    this.showAmountRange = false,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required FilterCriteria initialCriteria,
    required List<Map<String, String>> projects,
    required List<Map<String, String>> categories,
    List<Map<String, String>> employees = const [],
    bool showEmployeeFilter = false,
    bool showStatusFilter = true,
    bool showAmountRange = false,
    required ValueChanged<FilterCriteria> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.getSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.75,
        child: CustomFilterPanel(
          initialCriteria: initialCriteria,
          projects: projects,
          categories: categories,
          employees: employees,
          showEmployeeFilter: showEmployeeFilter,
          showStatusFilter: showStatusFilter,
          showAmountRange: showAmountRange,
          onApply: onApply,
        ),
      ),
    );
  }

  @override
  State<CustomFilterPanel> createState() => _CustomFilterPanelState();
}

class _CustomFilterPanelState extends State<CustomFilterPanel> {
  late FilterCriteria _criteria;

  @override
  void initState() {
    super.initState();
    _criteria = widget.initialCriteria;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.getBorder(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filter Results', style: AppTextStyles.titleMedium),
              TextButton(
                onPressed: () {
                  setState(() {
                    _criteria = const FilterCriteria();
                  });
                },
                child: Text(
                  'Reset All',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson),
                ),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                // Project Filter
                const SizedBox(height: 10),
                Text('Project', style: AppTextStyles.labelMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All Projects'),
                      selected: _criteria.projectId == null,
                      onSelected: (selected) {
                        if (selected) setState(() => _criteria = _criteria.copyWith(clearProject: true));
                      },
                    ),
                    ...widget.projects.map((p) => ChoiceChip(
                          label: Text(p['name'] ?? ''),
                          selected: _criteria.projectId == p['id'],
                          onSelected: (selected) {
                            setState(() {
                              _criteria = _criteria.copyWith(
                                projectId: selected ? p['id'] : null,
                                clearProject: !selected,
                              );
                            });
                          },
                        )),
                  ],
                ),
                // Category Filter
                const SizedBox(height: 16),
                Text('Category', style: AppTextStyles.labelMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All Categories'),
                      selected: _criteria.categoryId == null,
                      onSelected: (selected) {
                        if (selected) setState(() => _criteria = _criteria.copyWith(clearCategory: true));
                      },
                    ),
                    ...widget.categories.map((c) => ChoiceChip(
                          label: Text(c['name'] ?? ''),
                          selected: _criteria.categoryId == c['id'],
                          onSelected: (selected) {
                            setState(() {
                              _criteria = _criteria.copyWith(
                                categoryId: selected ? c['id'] : null,
                                clearCategory: !selected,
                              );
                            });
                          },
                        )),
                  ],
                ),
                // Status Filter
                if (widget.showStatusFilter) ...[
                  const SizedBox(height: 16),
                  Text('Approval Status', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _criteria.status == null,
                        onSelected: (selected) {
                          if (selected) setState(() => _criteria = _criteria.copyWith(clearStatus: true));
                        },
                      ),
                      ...ExpenseStatus.values.map((s) => ChoiceChip(
                            label: Text(s.displayName),
                            selected: _criteria.status == s,
                            onSelected: (selected) {
                              setState(() {
                                _criteria = _criteria.copyWith(
                                  status: selected ? s : null,
                                  clearStatus: !selected,
                                );
                              });
                            },
                          )),
                    ],
                  ),
                ],
                // Employee Filter (Manager / Admin / Finance)
                if (widget.showEmployeeFilter && widget.employees.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Employee', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All Employees'),
                        selected: _criteria.employeeId == null,
                        onSelected: (selected) {
                          if (selected) setState(() => _criteria = _criteria.copyWith(clearEmployee: true));
                        },
                      ),
                      ...widget.employees.map((e) => ChoiceChip(
                            label: Text(e['name'] ?? ''),
                            selected: _criteria.employeeId == e['id'],
                            onSelected: (selected) {
                              setState(() {
                                _criteria = _criteria.copyWith(
                                  employeeId: selected ? e['id'] : null,
                                  clearEmployee: !selected,
                                );
                              });
                            },
                          )),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
          // Apply Button
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_criteria);
                  Navigator.pop(context);
                },
                child: const Text('Apply Filters'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
