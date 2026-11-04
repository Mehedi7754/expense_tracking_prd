import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../widgets/notification_banner.dart';
import '../../models/project_model.dart';
import '../../state/expense_provider.dart';
import '../../state/export_service.dart';
import '../../state/project_provider.dart';

enum ExportScope {
  financialOverview,
  perProject,
}

enum ExportFormat {
  pdf,
  excel,
  word,
  csv,
}

class ReportExportBottomSheet extends ConsumerStatefulWidget {
  final ProjectModel? initialProject;

  const ReportExportBottomSheet({
    super.key,
    this.initialProject,
  });

  static Future<void> show(BuildContext context, {ProjectModel? initialProject}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReportExportBottomSheet(initialProject: initialProject),
    );
  }

  @override
  ConsumerState<ReportExportBottomSheet> createState() => _ReportExportBottomSheetState();
}

class _ReportExportBottomSheetState extends ConsumerState<ReportExportBottomSheet> {
  late ExportScope _scope;
  ExportFormat _format = ExportFormat.pdf;
  ProjectModel? _selectedProject;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialProject != null) {
      _scope = ExportScope.perProject;
      _selectedProject = widget.initialProject;
    } else {
      _scope = ExportScope.financialOverview;
    }
  }

  Future<void> _handleExport({bool isPreviewOnly = false}) async {
    setState(() => _isExporting = true);

    try {
      final projects = ref.read(projectProvider);
      final expenses = ref.read(expenseProvider);

      if (_scope == ExportScope.perProject && _selectedProject == null) {
        if (projects.isNotEmpty) {
          _selectedProject = projects.first;
        } else {
          NotificationBanner.showError(context, 'No project available to export.');
          setState(() => _isExporting = false);
          return;
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      if (_format == ExportFormat.pdf) {
        final pdfBytes = _scope == ExportScope.financialOverview
            ? await ExportService.generateFinancialOverviewPdf(projects, expenses)
            : await ExportService.generateProjectDetailPdf(_selectedProject!, expenses);

        final fileName = _scope == ExportScope.financialOverview
            ? 'financial_overview_$timestamp.pdf'
            : '${_selectedProject!.projectId}_report_$timestamp.pdf';

        if (isPreviewOnly) {
          await ExportService.previewOrPrintPdf(bytes: pdfBytes, fileName: fileName);
        } else {
          await ExportService.saveAndShare(
            bytes: pdfBytes,
            fileName: fileName,
            mimeType: 'application/pdf',
            subject: 'Financial Report: $fileName',
          );
          if (mounted) {
            NotificationBanner.showSuccess(context, 'PDF report generated & ready to share!');
            Navigator.pop(context);
          }
        }
      } else if (_format == ExportFormat.excel) {
        final excelContent = _scope == ExportScope.financialOverview
            ? ExportService.generateFinancialOverviewExcel(projects, expenses)
            : ExportService.generateProjectDetailExcel(_selectedProject!, expenses);

        final fileName = _scope == ExportScope.financialOverview
            ? 'financial_overview_$timestamp.xls'
            : '${_selectedProject!.projectId}_report_$timestamp.xls';

        final bytes = utf8.encode(excelContent);
        await ExportService.saveAndShare(
          bytes: bytes,
          fileName: fileName,
          mimeType: 'application/vnd.ms-excel',
          subject: 'Excel Workbook: $fileName',
        );

        if (mounted) {
          NotificationBanner.showSuccess(context, 'Excel spreadsheet generated & ready to share!');
          Navigator.pop(context);
        }
      } else if (_format == ExportFormat.word) {
        final wordContent = _scope == ExportScope.financialOverview
            ? ExportService.generateFinancialOverviewWord(projects, expenses)
            : ExportService.generateProjectDetailWord(_selectedProject!, expenses);

        final fileName = _scope == ExportScope.financialOverview
            ? 'financial_overview_$timestamp.doc'
            : '${_selectedProject!.projectId}_report_$timestamp.doc';

        final bytes = utf8.encode(wordContent);
        await ExportService.saveAndShare(
          bytes: bytes,
          fileName: fileName,
          mimeType: 'application/msword',
          subject: 'Word Document: $fileName',
        );

        if (mounted) {
          NotificationBanner.showSuccess(context, 'Word document generated & ready to share!');
          Navigator.pop(context);
        }
      } else {
        // CSV
        final csvContent = _scope == ExportScope.financialOverview
            ? ExportService.generateFinancialOverviewCsv(projects, expenses)
            : ExportService.generateProjectDetailCsv(_selectedProject!, expenses);

        final fileName = _scope == ExportScope.financialOverview
            ? 'financial_overview_$timestamp.csv'
            : '${_selectedProject!.projectId}_report_$timestamp.csv';

        final bytes = utf8.encode(csvContent);
        await ExportService.saveAndShare(
          bytes: bytes,
          fileName: fileName,
          mimeType: 'text/csv',
          subject: 'CSV Report: $fileName',
        );

        if (mounted) {
          NotificationBanner.showSuccess(context, 'CSV spreadsheet generated & ready to share!');
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationBanner.showError(context, 'Failed to export report: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projects = ref.watch(projectProvider);

    if (_selectedProject == null && projects.isNotEmpty) {
      _selectedProject = widget.initialProject ?? projects.first;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.file_download_outlined, color: Color(0xFF4F46E5), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export Financial Report',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select report scope and download format',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 1. Report Scope Selection
          Text(
            '1. REPORT SCOPE',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildScopeOption(
                  title: 'Financial Overview',
                  subtitle: 'All projects & portfolio',
                  icon: Icons.account_balance_wallet_outlined,
                  isSelected: _scope == ExportScope.financialOverview,
                  onTap: () => setState(() => _scope = ExportScope.financialOverview),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildScopeOption(
                  title: 'Per Project',
                  subtitle: 'Single project details',
                  icon: Icons.assignment_outlined,
                  isSelected: _scope == ExportScope.perProject,
                  onTap: () => setState(() => _scope = ExportScope.perProject),
                  isDark: isDark,
                ),
              ),
            ],
          ),

          // Dropdown for Per Project
          if (_scope == ExportScope.perProject) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedProject?.id,
                  hint: Text(
                    'Select a project to export',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  items: projects.map((p) {
                    return DropdownMenuItem<String>(
                      value: p.id,
                      child: Text(
                        '${p.projectId} - ${p.name}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id != null) {
                      setState(() {
                        _selectedProject = projects.firstWhere((p) => p.id == id);
                      });
                    }
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 2. Export Format Selection
          Text(
            '2. CHOOSE FORMAT',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildFormatCard(
                  format: ExportFormat.pdf,
                  title: 'PDF Document',
                  badge: 'Official / Printable',
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: const Color(0xFFE11D48),
                  isSelected: _format == ExportFormat.pdf,
                  onTap: () => setState(() => _format = ExportFormat.pdf),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFormatCard(
                  format: ExportFormat.excel,
                  title: 'Excel Workbook',
                  badge: 'Spreadsheet (.xls)',
                  icon: Icons.grid_on_rounded,
                  iconColor: const Color(0xFF059669),
                  isSelected: _format == ExportFormat.excel,
                  onTap: () => setState(() => _format = ExportFormat.excel),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFormatCard(
                  format: ExportFormat.word,
                  title: 'Word Document',
                  badge: 'Formatted (.doc)',
                  icon: Icons.description_rounded,
                  iconColor: const Color(0xFF2563EB),
                  isSelected: _format == ExportFormat.word,
                  onTap: () => setState(() => _format = ExportFormat.word),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFormatCard(
                  format: ExportFormat.csv,
                  title: 'CSV Data',
                  badge: 'Raw Data (.csv)',
                  icon: Icons.table_chart_rounded,
                  iconColor: const Color(0xFFD97706),
                  isSelected: _format == ExportFormat.csv,
                  onTap: () => setState(() => _format = ExportFormat.csv),
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Action Buttons
          if (_isExporting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Generating report...',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text(
                  _format == ExportFormat.pdf
                      ? 'Download / Share PDF'
                      : _format == ExportFormat.excel
                          ? 'Download / Share Excel (.xls)'
                          : _format == ExportFormat.word
                              ? 'Download / Share Word (.doc)'
                              : 'Download / Share CSV Data',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onPressed: () => _handleExport(isPreviewOnly: false),
              ),
            ),

            if (_format == ExportFormat.pdf) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    side: const BorderSide(color: Color(0xFF4F46E5), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text(
                    'Preview & Print PDF',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  onPressed: () => _handleExport(isPreviewOnly: true),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildScopeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (const Color(0xFF4F46E5).withAlpha(isDark ? 50 : 25))
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF4F46E5) : (isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatCard({
    required ExportFormat format,
    required String title,
    required String badge,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? (const Color(0xFF4F46E5).withAlpha(isDark ? 45 : 20))
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF4F46E5), size: 18)
                else
                  Icon(Icons.radio_button_unchecked, color: isDark ? Colors.white30 : const Color(0xFFCBD5E1), size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              badge,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
