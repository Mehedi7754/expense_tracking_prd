import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/report_filters.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/project_model.dart';
import '../../models/user_model.dart';
import '../../state/attendance_provider.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/export_service.dart';
import '../../state/leave_provider.dart';
import '../../state/project_provider.dart';
import '../../state/task_provider.dart';
import '../../state/user_management_provider.dart';

enum _ReportKind { financial, expenses, tasks, leaves, attendance }

enum _ReportFormat { csv, excel, pdf, word }

extension on _ReportKind {
  String get label => switch (this) {
    _ReportKind.financial => 'Project financials',
    _ReportKind.expenses => 'Expenses',
    _ReportKind.tasks => 'Tasks',
    _ReportKind.leaves => 'Leave requests',
    _ReportKind.attendance => 'Attendance',
  };
  IconData get icon => switch (this) {
    _ReportKind.financial => Icons.account_balance_wallet_outlined,
    _ReportKind.expenses => Icons.receipt_long_outlined,
    _ReportKind.tasks => Icons.task_alt_rounded,
    _ReportKind.leaves => Icons.event_busy_outlined,
    _ReportKind.attendance => Icons.location_on_outlined,
  };
  List<String> get columns => switch (this) {
    _ReportKind.financial => [
      'Project',
      'Client',
      'Contract value',
      'Budget',
      'Status',
    ],
    _ReportKind.expenses => [
      'Date',
      'Project',
      'Employee',
      'Category',
      'Amount',
      'Status',
    ],
    _ReportKind.tasks => [
      'Task',
      'Project',
      'Assignees',
      'Due date',
      'Priority',
      'Status',
    ],
    _ReportKind.leaves => [
      'Employee',
      'Leave type',
      'Start date',
      'End date',
      'Days',
      'Status',
    ],
    _ReportKind.attendance => [
      'Employee',
      'Date',
      'Check-in',
      'Work location',
      'Department',
      'Status',
    ],
  };
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _ReportKind _kind = _ReportKind.financial;
  ReportFilters _filters = const ReportFilters();
  final _searchController = TextEditingController();
  final _reportKindController = ScrollController();
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReports());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _reportKindController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final user = ref.read(authProvider).currentUser;
    final jobs = <Future<void>>[
      ref.read(projectProvider.notifier).fetchProjects(force: true),
      ref.read(expenseProvider.notifier).fetchExpenses(force: true),
      ref.read(userManagementProvider.notifier).fetchUsers(force: true),
    ];
    if (user != null) {
      jobs.add(
        ref
            .read(taskProvider.notifier)
            .fetchTasks(
              assigneeId: user.role.canCreateProject ? null : user.id,
            ),
      );
      jobs.add(ref.read(leaveProvider.notifier).fetchLeaves(force: true));
      jobs.add(
        ref
            .read(attendanceProvider.notifier)
            .fetchAttendanceRecords(force: true),
      );
    }
    await Future.wait(jobs.map((job) => job.catchError((_) {})));
    if (mounted) setState(() => _refreshing = false);
  }

  void _selectReportKind(_ReportKind kind) {
    setState(() {
      _kind = kind;
      _filters = const ReportFilters();
    });
    if (_reportKindController.hasClients) {
      final index = _ReportKind.values.indexOf(kind);
      _reportKindController.animateTo(
        (index * 134.0)
            .clamp(0, _reportKindController.position.maxScrollExtent)
            .toDouble(),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _showAllReportKinds() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'All reports',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  ..._ReportKind.values.map(
                    (kind) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(kind.icon, color: AppColors.indigo),
                      title: Text(kind.label),
                      trailing:
                          kind == _kind
                              ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.indigo,
                              )
                              : null,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _selectReportKind(kind);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  List<Map<String, dynamic>> _allRows() {
    switch (_kind) {
      case _ReportKind.financial:
        return ref
            .watch(projectProvider)
            .map(
              (p) => {
                'id': p.id,
                'projectId': p.id,
                'projectName': p.name,
                'client': p.client,
                'contractValue': p.grossProjectValue,
                'budget': p.budget,
                'date': p.startDate.toIso8601String(),
                'status': p.status.displayName,
              },
            )
            .toList();
      case _ReportKind.expenses:
        return ref
            .watch(expenseProvider)
            .map(
              (e) => {
                'id': e.id,
                'date': e.date.toIso8601String(),
                'projectId': e.projectId,
                'projectName': e.projectName,
                'employeeId': e.employeeId,
                'employeeName': e.employeeName,
                'category': e.categoryName,
                'amount': e.totalCost,
                'status': e.status.displayName,
                'description': e.note,
                'hasReceipt': e.hasReceipt,
              },
            )
            .toList();
      case _ReportKind.tasks:
        return ref
            .watch(taskProvider)
            .map(
              (t) => {
                'id': t.id,
                'projectId': t.projectId,
                'projectName': _projectName(t.projectId),
                'title': t.title,
                'description': t.description,
                'assigneeId': t.assigneeId,
                'assigneeIds': t.assigneeIds,
                'assignees': List.generate(
                  t.assigneeIds.length,
                  (i) => {
                    'id': t.assigneeIds[i],
                    'name':
                        i < t.assigneeNames.length ? t.assigneeNames[i] : '',
                  },
                ),
                'employeeName': t.assigneeNames.join(', '),
                'dueDate': t.dueDate.toIso8601String(),
                'priority': t.priority,
                'status': t.status.displayName,
              },
            )
            .toList();
      case _ReportKind.leaves:
        return ref
            .watch(leaveProvider)
            .leaves
            .map(
              (l) => {
                'id': l.id,
                'userId': l.userId,
                'employeeId': l.userId,
                'employeeName': l.userName,
                'leaveType': l.typeDisplayName,
                'category': l.typeDisplayName,
                'startDate': l.startDate,
                'endDate': l.endDate,
                'days': l.totalDays,
                'status': l.statusText,
                'reason': l.reason,
              },
            )
            .toList();
      case _ReportKind.attendance:
        return ref
            .watch(attendanceProvider)
            .records
            .map(
              (a) => {
                'id': a.id,
                'userId': a.userId,
                'employeeId': a.userId,
                'employeeName': a.userName,
                'date': a.date,
                'checkIn': a.formattedTime,
                'category': a.workModeLabel,
                'workLocation': a.workModeLabel,
                'department': a.department,
                'status': a.status,
              },
            )
            .toList();
    }
  }

  String _projectName(String id) {
    for (final project in ref.read(projectProvider)) {
      if (project.id == id) return project.name;
    }
    return '—';
  }

  List<Map<String, dynamic>> get _rows =>
      filterReportRows(_allRows(), _filters);

  List<String> _options(String key) =>
      _allRows()
          .map((row) => (row[key] ?? '').toString())
          .where((value) => value.isNotEmpty && value != '—')
          .toSet()
          .toList()
        ..sort();

  List<ProjectModel> get _projects => ref.watch(projectProvider);
  List<UserModel> get _users =>
      ref.watch(userManagementProvider).where((u) => u.isActive).toList();

  Future<void> _pickDate(bool from) async {
    final existing = DateTime.tryParse(
      from ? (_filters.from ?? '') : (_filters.to ?? ''),
    );
    final selected = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    final value = DateFormat('yyyy-MM-dd').format(selected);
    setState(
      () =>
          _filters = ReportFilters(
            from: from ? value : _filters.from,
            to: from ? _filters.to : value,
            projectId: _filters.projectId,
            status: _filters.status,
            category: _filters.category,
            userId: _filters.userId,
            search: _filters.search,
          ),
    );
  }

  void _setFilter(String field, String? value) {
    setState(
      () =>
          _filters = switch (field) {
            'project' => _filters.copyWith(
              projectId: value == 'all' ? null : value,
              clearProject: value == 'all',
            ),
            'status' => _filters.copyWith(
              status: value == 'all' ? null : value,
              clearStatus: value == 'all',
            ),
            'category' => _filters.copyWith(
              category: value == 'all' ? null : value,
              clearCategory: value == 'all',
            ),
            'user' => _filters.copyWith(
              userId: value == 'all' ? null : value,
              clearUser: value == 'all',
            ),
            _ => _filters,
          },
    );
  }

  Future<void> _export(
    _ReportFormat format, {
    Map<String, dynamic>? row,
  }) async {
    final rows = row == null ? _rows : [row];
    if (rows.isEmpty) return;
    final headers = _kind.columns;
    final keys = switch (_kind) {
      _ReportKind.financial => [
        'projectName',
        'client',
        'contractValue',
        'budget',
        'status',
      ],
      _ReportKind.expenses => [
        'date',
        'projectName',
        'employeeName',
        'category',
        'amount',
        'status',
      ],
      _ReportKind.tasks => [
        'title',
        'projectName',
        'employeeName',
        'dueDate',
        'priority',
        'status',
      ],
      _ReportKind.leaves => [
        'employeeName',
        'leaveType',
        'startDate',
        'endDate',
        'days',
        'status',
      ],
      _ReportKind.attendance => [
        'employeeName',
        'date',
        'checkIn',
        'workLocation',
        'department',
        'status',
      ],
    };
    final name =
        '${_kind.name}_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
    final values =
        rows
            .map((r) => keys.map((key) => _displayValue(r[key], key)).toList())
            .toList();
    try {
      if (format == _ReportFormat.pdf) {
        final doc = pw.Document();
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            build:
                (_) => [
                  pw.Text(
                    _kind.label,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  pw.TableHelper.fromTextArray(
                    headers: headers,
                    data: values,
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColors.indigo700,
                    ),
                    cellStyle: const pw.TextStyle(fontSize: 8),
                    cellPadding: const pw.EdgeInsets.all(6),
                  ),
                ],
          ),
        );
        final delivered = await _deliverExport(
          bytes: await doc.save(),
          fileName: '$name.pdf',
          mimeType: 'application/pdf',
        );
        if (!delivered) return;
      } else if (format == _ReportFormat.csv) {
        String quote(Object? v) =>
            '"${(v ?? '').toString().replaceAll('"', '""')}"';
        final csv = [
          headers.map(quote).join(','),
          ...values.map((r) => r.map(quote).join(',')),
        ].join('\r\n');
        final delivered = await _deliverExport(
          bytes: utf8.encode('\uFEFF$csv'),
          fileName: '$name.csv',
          mimeType: 'text/csv',
        );
        if (!delivered) return;
      } else if (format == _ReportFormat.excel) {
        final delivered = await _deliverExport(
          bytes: _buildXlsx(headers, values),
          fileName: '$name.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        if (!delivered) return;
      } else {
        final delivered = await _deliverExport(
          bytes: _buildDocx(_kind.label, headers, values),
          fileName: '$name.docx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
        if (!delivered) return;
      }
      if (mounted) {
        NotificationBanner.showSuccess(
          context,
          '${row == null ? rows.length.toString() : 'Record'} ${format.name.toUpperCase()} export is ready.',
        );
      }
    } catch (error) {
      if (mounted) {
        NotificationBanner.showError(context, 'Export failed: $error');
      }
    }
  }

  Future<bool> _deliverExport({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    if (kIsWeb) {
      final saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
        mimeType: mimeType,
      );
      return saved != null;
    }
    await ExportService.saveAndShare(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      subject: 'GW Project ${_kind.label} report',
    );
    return true;
  }

  String _displayValue(dynamic value, String key) {
    if (value == null || value.toString().isEmpty) return '—';
    if (key == 'amount' || key == 'budget' || key == 'contractValue') {
      return CurrencyFormatter.format((value as num).toDouble());
    }
    if (key.toLowerCase().contains('date')) {
      final date = DateTime.tryParse(value.toString());
      if (date != null) return DateFormat.yMMMd().format(date);
    }
    return value.toString();
  }

  List<int> _zip(Map<String, String> files) {
    final archive = Archive();
    for (final entry in files.entries) {
      final bytes = utf8.encode(entry.value);
      archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
    }
    return ZipEncoder().encode(archive);
  }

  List<int> _buildXlsx(List<String> headers, List<List<String>> rows) {
    final allRows = [headers, ...rows];
    final sheetRows =
        allRows.asMap().entries.map((rowEntry) {
          final rowNumber = rowEntry.key + 1;
          final cells =
              rowEntry.value.asMap().entries.map((cellEntry) {
                final ref = '${_excelColumn(cellEntry.key + 1)}$rowNumber';
                return '<c r="$ref" t="inlineStr"><is><t>${_xmlEscape(cellEntry.value)}</t></is></c>';
              }).join();
          return '<row r="$rowNumber">$cells</row>';
        }).join();
    return _zip({
      '[Content_Types].xml':
          '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
      '_rels/.rels':
          '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
      'xl/workbook.xml':
          '<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Report" sheetId="1" r:id="rId1"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels':
          '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
      'xl/worksheets/sheet1.xml':
          '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>$sheetRows</sheetData></worksheet>',
    });
  }

  String _excelColumn(int column) {
    var value = column;
    var result = '';
    while (value > 0) {
      final digit = (value - 1) % 26;
      result = String.fromCharCode(65 + digit) + result;
      value = (value - 1) ~/ 26;
    }
    return result;
  }

  List<int> _buildDocx(
    String title,
    List<String> headers,
    List<List<String>> rows,
  ) {
    String cell(String text, {bool header = false}) =>
        '<w:tc><w:tcPr><w:tcW w:w="2400" w:type="dxa"/>${header ? '<w:shd w:fill="E8EEF9"/>' : ''}</w:tcPr><w:p><w:r>${header ? '<w:rPr><w:b/></w:rPr>' : ''}<w:t xml:space="preserve">${_xmlEscape(text)}</w:t></w:r></w:p></w:tc>';
    final tableRows =
        [headers, ...rows]
            .asMap()
            .entries
            .map(
              (entry) =>
                  '<w:tr>${entry.value.map((value) => cell(value, header: entry.key == 0)).join()}</w:tr>',
            )
            .join();
    final document =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr><w:t>${_xmlEscape(title)}</w:t></w:r></w:p><w:tbl><w:tblPr><w:tblBorders><w:top w:val="single" w:sz="4" w:color="D9E1F2"/><w:left w:val="single" w:sz="4" w:color="D9E1F2"/><w:bottom w:val="single" w:sz="4" w:color="D9E1F2"/><w:right w:val="single" w:sz="4" w:color="D9E1F2"/><w:insideH w:val="single" w:sz="4" w:color="D9E1F2"/><w:insideV w:val="single" w:sz="4" w:color="D9E1F2"/></w:tblBorders></w:tblPr><w:tblGrid>${headers.map((_) => '<w:gridCol w:w="2400"/>').join()}</w:tblGrid>$tableRows</w:tbl><w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720"/></w:sectPr></w:body></w:document>';
    return _zip({
      '[Content_Types].xml':
          '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>',
      '_rels/.rels':
          '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>',
      'word/document.xml': document,
    });
  }

  String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCount =
        [
          _filters.from,
          _filters.to,
          _filters.projectId,
          _filters.status,
          _filters.category,
          _filters.userId,
          _filters.search,
        ].where((value) => value != null && value.isNotEmpty).length;
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh reports',
            onPressed: _refreshing ? null : _loadReports,
            icon:
                _refreshing
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<_ReportFormat>(
            tooltip: 'Export report',
            icon: const Icon(Icons.ios_share_rounded),
            onSelected: (format) => _export(format),
            itemBuilder:
                (_) => const [
                  PopupMenuItem(
                    value: _ReportFormat.csv,
                    child: Text('Export CSV'),
                  ),
                  PopupMenuItem(
                    value: _ReportFormat.excel,
                    child: Text('Export Excel'),
                  ),
                  PopupMenuItem(
                    value: _ReportFormat.pdf,
                    child: Text('Export PDF'),
                  ),
                  PopupMenuItem(
                    value: _ReportFormat.word,
                    child: Text('Export Word'),
                  ),
                ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReports,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 110),
          children: [
            Row(
              children: [
                Text(
                  'Choose a report',
                  style: TextStyle(
                    color: AppColors.getTextMuted(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showAllReportKinds,
                  icon: const Icon(Icons.grid_view_rounded, size: 15),
                  label: const Text('All 5'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.swipe_rounded,
                  size: 14,
                  color: AppColors.getTextMuted(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: Scrollbar(
                controller: _reportKindController,
                thumbVisibility: true,
                thickness: 2,
                radius: const Radius.circular(8),
                child: ListView(
                  controller: _reportKindController,
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 8),
                  children:
                      _ReportKind.values.map((kind) {
                        final selected = kind == _kind;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => _selectReportKind(kind),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 126,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    selected
                                        ? const Color(0xFFEEF2FF)
                                        : AppColors.getSurface(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      selected
                                          ? AppColors.indigo
                                          : AppColors.getBorder(context),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    kind.icon,
                                    size: 19,
                                    color:
                                        selected
                                            ? AppColors.indigo
                                            : AppColors.getTextMuted(context),
                                  ),
                                  Text(
                                    kind.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          selected
                                              ? AppColors.indigo
                                              : AppColors.getTextPrimary(
                                                context,
                                              ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildFilters(context),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${rows.length} records',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (activeCount > 0)
                  TextButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _filters = const ReportFilters());
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: Text('Clear $activeCount'),
                  ),
                PopupMenuButton<_ReportFormat>(
                  tooltip: 'Export filtered rows',
                  onSelected: (format) => _export(format),
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(
                          value: _ReportFormat.csv,
                          child: Text('CSV'),
                        ),
                        PopupMenuItem(
                          value: _ReportFormat.excel,
                          child: Text('Excel'),
                        ),
                        PopupMenuItem(
                          value: _ReportFormat.pdf,
                          child: Text('PDF'),
                        ),
                        PopupMenuItem(
                          value: _ReportFormat.word,
                          child: Text('Word'),
                        ),
                      ],
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.download_outlined),
                  ),
                ),
              ],
            ),
            if (rows.isEmpty)
              _emptyState(context, isDark)
            else
              ...rows.map((row) => _recordCard(context, row)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged:
                (value) => setState(
                  () =>
                      _filters = _filters.copyWith(
                        search: value,
                        clearSearch: value.isEmpty,
                      ),
                ),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search records',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterDropdown(context, 'Project', _filters.projectId, {
                'all': 'All projects',
                for (final p in _projects) p.id: p.name,
              }, 'project'),
              _filterDropdown(context, 'Employee', _filters.userId, {
                'all': 'All employees',
                for (final u in _users) u.id: u.name,
              }, 'user'),
              _filterDropdown(context, 'Status', _filters.status, {
                'all': 'All statuses',
                for (final s in _options('status')) s.toLowerCase(): s,
              }, 'status'),
              if (_kind == _ReportKind.expenses ||
                  _kind == _ReportKind.leaves ||
                  _kind == _ReportKind.attendance)
                _filterDropdown(
                  context,
                  _kind == _ReportKind.attendance
                      ? 'Work location'
                      : _kind == _ReportKind.leaves
                      ? 'Leave type'
                      : 'Category',
                  _filters.category,
                  {
                    'all':
                        'All ${_kind == _ReportKind.attendance
                            ? 'locations'
                            : _kind == _ReportKind.leaves
                            ? 'leave types'
                            : 'categories'}',
                    for (final s in _options(
                      _kind == _ReportKind.attendance
                          ? 'workLocation'
                          : _kind == _ReportKind.leaves
                          ? 'leaveType'
                          : 'category',
                    ))
                      s.toLowerCase(): s,
                  },
                  'category',
                ),
              _dateButton(context, 'From', _filters.from, true),
              _dateButton(context, 'To', _filters.to, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown(
    BuildContext context,
    String label,
    String? value,
    Map<String, String> values,
    String field,
  ) {
    final selected =
        value == null || !values.containsKey(value) ? 'all' : value;
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        isExpanded: true,
        isDense: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 8,
          ),
        ),
        items:
            values.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
        onChanged: (value) => _setFilter(field, value),
      ),
    );
  }

  Widget _dateButton(
    BuildContext context,
    String label,
    String? value,
    bool from,
  ) => OutlinedButton.icon(
    onPressed: () => _pickDate(from),
    icon: const Icon(Icons.calendar_today_outlined, size: 14),
    label: Text(
      value == null
          ? label
          : '$label ${DateFormat.Md().format(DateTime.parse(value))}',
      style: const TextStyle(fontSize: 11),
    ),
  );

  Widget _recordCard(BuildContext context, Map<String, dynamic> row) {
    final data = _kind.columns;
    final keys = switch (_kind) {
      _ReportKind.financial => [
        'projectName',
        'client',
        'contractValue',
        'budget',
        'status',
      ],
      _ReportKind.expenses => [
        'date',
        'projectName',
        'employeeName',
        'category',
        'amount',
        'status',
      ],
      _ReportKind.tasks => [
        'title',
        'projectName',
        'employeeName',
        'dueDate',
        'priority',
        'status',
      ],
      _ReportKind.leaves => [
        'employeeName',
        'leaveType',
        'startDate',
        'endDate',
        'days',
        'status',
      ],
      _ReportKind.attendance => [
        'employeeName',
        'date',
        'checkIn',
        'workLocation',
        'department',
        'status',
      ],
    };
    final title = _displayValue(row[keys.first], keys.first);
    final status = (row['status'] ?? '').toString();
    final tone = _statusColor(status);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.getBorder(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (status.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: tone,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                PopupMenuButton<_ReportFormat>(
                  tooltip: 'Export this record',
                  onSelected: (format) => _export(format, row: row),
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(
                          value: _ReportFormat.csv,
                          child: Text('Export CSV'),
                        ),
                        PopupMenuItem(
                          value: _ReportFormat.pdf,
                          child: Text('Export PDF'),
                        ),
                      ],
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(Icons.more_horiz_rounded, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 14,
              runSpacing: 5,
              children: [
                for (var i = 1; i < keys.length; i++)
                  if (keys[i] != 'status' &&
                      row[keys[i]] != null &&
                      row[keys[i]].toString().isNotEmpty)
                    Text(
                      '${data[i]}: ${_displayValue(row[keys[i]], keys[i])}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.getTextMuted(context),
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    final v = status.toLowerCase();
    if (v.contains('approv') ||
        v.contains('complete') ||
        v.contains('present') ||
        v.contains('ongoing')) {
      return AppColors.emerald;
    }
    if (v.contains('reject') || v.contains('overdue') || v.contains('absent')) {
      return AppColors.crimson;
    }
    if (v.contains('pending') ||
        v.contains('progress') ||
        v.contains('review')) {
      return AppColors.amber;
    }
    return AppColors.indigo;
  }

  Widget _emptyState(BuildContext context, bool isDark) => Padding(
    padding: const EdgeInsets.only(top: 42),
    child: Column(
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 38,
          color: AppColors.getTextMuted(context),
        ),
        const SizedBox(height: 10),
        Text(
          'No ${_kind.label.toLowerCase()} found',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Try changing the filters or refresh the report.',
          style: TextStyle(
            color: AppColors.getTextMuted(context),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
