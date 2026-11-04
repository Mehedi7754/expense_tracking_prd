import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/utils/date_formatter.dart';
import '../models/expense_model.dart';
import '../models/project_model.dart';

class ExportService {
  ExportService._();

  /// Generates CSV format for Projects Portfolio (PRD Section 3 & 25)
  static String exportProjectsToCsv(List<ProjectModel> projects, List<ExpenseModel> expenses) {
    return generateFinancialOverviewCsv(projects, expenses);
  }

  /// Generates CSV format for Expenses & Receipts (PRD Section 6, 10, 25)
  static String exportExpensesToCsv(List<ExpenseModel> expenses) {
    final buffer = StringBuffer();
    buffer.writeln('Expense ID,Date,Project Name,Category,Base Cost (BDT),VAT (BDT),Tax (BDT),Office Benefit 30% (BDT),Total Cost (BDT),Entered By,Receipt Available,Receipt Status,Approval Status,Justification Status,Purpose/Note');

    for (final e in expenses) {
      buffer.writeln(
        '"${e.id}",'
        '"${e.date.toIso8601String().split('T').first}",'
        '"${e.projectName.replaceAll('"', '""')}",'
        '"${e.categoryName}",'
        '${e.baseCost.toStringAsFixed(2)},'
        '${e.vatAmount.toStringAsFixed(2)},'
        '${e.taxAmount.toStringAsFixed(2)},'
        '${e.officeBenefitAmount.toStringAsFixed(2)},'
        '${e.totalCost.toStringAsFixed(2)},'
        '"${e.employeeName.replaceAll('"', '""')}",'
        '"${e.hasReceipt ? 'YES' : 'NO'}",'
        '"${e.hasReceipt ? 'Verified' : 'Unreceipted'}",'
        '"${e.status.displayName}",'
        '"${e.justificationStatus.displayName}",'
        '"${e.note.replaceAll('"', '""')}"',
      );
    }

    return buffer.toString();
  }

  /// Generates CSV format for Financial Overview
  static String generateFinancialOverviewCsv(List<ProjectModel> projects, List<ExpenseModel> expenses) {
    final buffer = StringBuffer();
    buffer.writeln('Project ID,Project Name,Client,Client Type,Assignment Type,Status,Gross Contract Value (BDT),Cost Incurred (BDT),Projected Remaining (BDT),Projected Final Cost (BDT),Projected Profit (BDT),Projected Margin (%),Amount Received (BDT),Amount Receivable (BDT)');

    for (final p in projects) {
      final projectExpenses = expenses.where((e) => e.projectId == p.id && e.status == ExpenseStatus.approved).toList();
      final directCost = projectExpenses.fold<double>(0.0, (sum, e) => sum + e.totalCost);
      final officeBenefit = directCost * p.officeBenefitRate;
      final totalCostIncurred = directCost + officeBenefit;
      final projectedFinalCost = totalCostIncurred + p.estimatedRemainingCost;
      final projectedProfit = p.grossProjectValue - projectedFinalCost;
      final projectedMargin = p.grossProjectValue > 0 ? (projectedProfit / p.grossProjectValue) * 100 : 0.0;

      buffer.writeln(
        '"${p.projectId}",'
        '"${p.name.replaceAll('"', '""')}",'
        '"${p.client.replaceAll('"', '""')}",'
        '"${p.clientType.displayName}",'
        '"${p.assignmentType.displayName}",'
        '"${p.status.displayName}",'
        '${p.grossProjectValue.toStringAsFixed(2)},'
        '${totalCostIncurred.toStringAsFixed(2)},'
        '${p.estimatedRemainingCost.toStringAsFixed(2)},'
        '${projectedFinalCost.toStringAsFixed(2)},'
        '${projectedProfit.toStringAsFixed(2)},'
        '${projectedMargin.toStringAsFixed(1)},'
        '${p.amountReceived.toStringAsFixed(2)},'
        '${p.amountReceivable.toStringAsFixed(2)}',
      );
    }

    return buffer.toString();
  }

  /// Generates CSV format for Budget vs Actual (PRD Section 14 & 25)
  static String exportBudgetVsActualToCsv(ProjectModel project, List<ExpenseModel> projectExpenses) {
    return generateProjectDetailCsv(project, projectExpenses);
  }

  /// Generates CSV format for a Single Project Detail
  static String generateProjectDetailCsv(ProjectModel project, List<ExpenseModel> projectExpenses) {
    final buffer = StringBuffer();
    buffer.writeln('Project: ${project.name} (${project.projectId})');
    buffer.writeln('Contract Value: BDT ${project.grossProjectValue.toStringAsFixed(2)}');
    buffer.writeln('Status: ${project.status.displayName}');
    buffer.writeln('');
    buffer.writeln('Cost Category,Budget (BDT),Actual Incurred (BDT),Remaining (BDT),Variance (%),Status');

    final categories = ['Equipment', 'Transportation', 'Food', 'Accommodation', 'Office Cost'];
    double totalBudget = 0.0;
    double totalActual = 0.0;

    for (final cat in categories) {
      final budget = project.categoryBudgets[cat.toLowerCase().replaceAll(' ', '')] ?? 0.0;
      final actual = projectExpenses
          .where((e) => e.status == ExpenseStatus.approved && e.categoryName.toLowerCase().contains(cat.toLowerCase().split(' ').first))
          .fold<double>(0.0, (sum, e) => sum + e.totalCost);

      final remaining = budget - actual;
      final variance = budget > 0 ? ((actual - budget) / budget) * 100 : 0.0;
      final status = actual > budget ? 'OVER BUDGET' : (actual >= budget * 0.8 ? 'APPROACHING' : 'ON TRACK');

      totalBudget += budget;
      totalActual += actual;

      buffer.writeln(
        '"$cat",'
        '${budget.toStringAsFixed(2)},'
        '${actual.toStringAsFixed(2)},'
        '${remaining.toStringAsFixed(2)},'
        '${variance.toStringAsFixed(1)}%,'
        '"$status"',
      );
    }

    final officeBenefitBudget = project.categoryBudgets['officebenefit'] ?? (totalBudget * project.officeBenefitRate);
    final officeBenefitActual = totalActual * project.officeBenefitRate;
    final officeBenefitRemaining = officeBenefitBudget - officeBenefitActual;
    final obVariance = officeBenefitBudget > 0 ? ((officeBenefitActual - officeBenefitBudget) / officeBenefitBudget) * 100 : 0.0;

    buffer.writeln(
      '"Office Benefit (${(project.officeBenefitRate * 100).toInt()}%)",'
      '${officeBenefitBudget.toStringAsFixed(2)},'
      '${officeBenefitActual.toStringAsFixed(2)},'
      '${officeBenefitRemaining.toStringAsFixed(2)},'
      '${obVariance.toStringAsFixed(1)}%,'
      '"CALCULATED"',
    );

    final grandBudget = totalBudget + officeBenefitBudget;
    final grandActual = totalActual + officeBenefitActual;
    final grandRemaining = grandBudget - grandActual;

    buffer.writeln('');
    buffer.writeln(
      '"TOTAL",'
      '${grandBudget.toStringAsFixed(2)},'
      '${grandActual.toStringAsFixed(2)},'
      '${grandRemaining.toStringAsFixed(2)},'
      '${grandBudget > 0 ? (((grandActual - grandBudget) / grandBudget) * 100).toStringAsFixed(1) : '0.0'}%,'
      '"${grandActual > grandBudget ? 'OVER BUDGET' : 'ON TRACK'}"',
    );

    buffer.writeln('');
    buffer.writeln('Recent Project Expenses');
    buffer.writeln('Date,Category,Employee,Base Cost (BDT),VAT (BDT),Tax (BDT),Total (BDT),Receipt,Status');
    for (final exp in projectExpenses) {
      buffer.writeln(
        '"${exp.date.toIso8601String().split('T').first}",'
        '"${exp.categoryName}",'
        '"${exp.employeeName.replaceAll('"', '""')}",'
        '${exp.baseCost.toStringAsFixed(2)},'
        '${exp.vatAmount.toStringAsFixed(2)},'
        '${exp.taxAmount.toStringAsFixed(2)},'
        '${exp.totalCost.toStringAsFixed(2)},'
        '"${exp.hasReceipt ? 'Yes' : 'No'}",'
        '"${exp.status.displayName}"',
      );
    }

    return buffer.toString();
  }

  /// Generates clean PDF for Financial Overview
  static Future<Uint8List> generateFinancialOverviewPdf(List<ProjectModel> projects, List<ExpenseModel> expenses) async {
    final pdf = pw.Document();

    double totalPortfolioValue = 0.0;
    double totalIncurred = 0.0;
    for (final p in projects) {
      totalPortfolioValue += p.grossProjectValue;
      final pExps = expenses.where((e) => e.projectId == p.id && e.status == ExpenseStatus.approved).toList();
      final direct = pExps.fold<double>(0.0, (sum, e) => sum + e.totalCost);
      totalIncurred += direct + (direct * p.officeBenefitRate);
    }
    final netProfit = totalPortfolioValue - totalIncurred;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('GW PROJECT & PORTFOLIO MANAGEMENT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  pw.Text('Corporate Financial Overview & Budget Audit', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
              pw.Text(
                'Date: ${DateFormatter.formatShort(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Divider(color: PdfColors.indigo400, thickness: 1.5),
          pw.SizedBox(height: 12),

          // Summary KPI boxes
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfKpiCard('Total Projects', '${projects.length}', PdfColors.blueGrey800),
              _buildPdfKpiCard('Contract Value', 'BDT ${totalPortfolioValue.toStringAsFixed(0)}', PdfColors.indigo700),
              _buildPdfKpiCard('Total Incurred', 'BDT ${totalIncurred.toStringAsFixed(0)}', PdfColors.amber800),
              _buildPdfKpiCard('Net Profit', 'BDT ${netProfit.toStringAsFixed(0)}', netProfit >= 0 ? PdfColors.green700 : PdfColors.red700),
            ],
          ),
          pw.SizedBox(height: 20),

          // Projects Table
          pw.Text('Project Portfolio Breakdown', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Code', 'Project Name', 'Client', 'Contract (BDT)', 'Incurred (BDT)', 'Status'],
            data: projects.map((p) {
              final pExps = expenses.where((e) => e.projectId == p.id && e.status == ExpenseStatus.approved).toList();
              final direct = pExps.fold<double>(0.0, (sum, e) => sum + e.totalCost);
              final incurred = direct + (direct * p.officeBenefitRate);
              return [
                p.projectId,
                p.name,
                p.client,
                p.grossProjectValue.toStringAsFixed(0),
                incurred.toStringAsFixed(0),
                p.status.displayName,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Generates clean PDF for a Single Project Detail & Budget
  static Future<Uint8List> generateProjectDetailPdf(ProjectModel project, List<ExpenseModel> projectExpenses) async {
    final pdf = pw.Document();

    final directCost = projectExpenses.where((e) => e.status == ExpenseStatus.approved).fold<double>(0.0, (sum, e) => sum + e.totalCost);
    final officeBenefit = directCost * project.officeBenefitRate;
    final totalSpent = directCost + officeBenefit;
    final remainingBudget = project.grossProjectValue - totalSpent;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('GW PROJECT: ${project.name.toUpperCase()}', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  pw.Text('Project Code: ${project.projectId} | Client: ${project.client}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
              pw.Text(
                'Report Date: ${DateFormatter.formatShort(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.indigo400, thickness: 1.5),
          pw.SizedBox(height: 10),

          // KPI metrics
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfKpiCard('Contract Value', 'BDT ${project.grossProjectValue.toStringAsFixed(0)}', PdfColors.indigo700),
              _buildPdfKpiCard('Direct Expenses', 'BDT ${directCost.toStringAsFixed(0)}', PdfColors.blueGrey800),
              _buildPdfKpiCard('Office Benefit (30%)', 'BDT ${officeBenefit.toStringAsFixed(0)}', PdfColors.amber800),
              _buildPdfKpiCard('Remaining Budget', 'BDT ${remainingBudget.toStringAsFixed(0)}', remainingBudget >= 0 ? PdfColors.green700 : PdfColors.red700),
            ],
          ),
          pw.SizedBox(height: 16),

          // Category Budget vs Actual
          pw.Text('Category Budgets & Actual Expenditure', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Category', 'Budget (BDT)', 'Actual (BDT)', 'Remaining (BDT)', 'Status'],
            data: ['Equipment', 'Transportation', 'Food', 'Accommodation', 'Office Cost'].map((cat) {
              final b = project.categoryBudgets[cat.toLowerCase().replaceAll(' ', '')] ?? 0.0;
              final a = projectExpenses
                  .where((e) => e.status == ExpenseStatus.approved && e.categoryName.toLowerCase().contains(cat.toLowerCase().split(' ').first))
                  .fold<double>(0.0, (sum, e) => sum + e.totalCost);
              final r = b - a;
              final st = a > b ? 'Over Budget' : (a >= b * 0.8 ? 'Approaching' : 'On Track');
              return [cat, b.toStringAsFixed(0), a.toStringAsFixed(0), r.toStringAsFixed(0), st];
            }).toList(),
            headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          ),
          pw.SizedBox(height: 16),

          // Recent Expense Items with VAT & Tax Itemization
          pw.Text('Itemized Project Expenses (With VAT & Tax)', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Category', 'Claimant', 'Base Cost', 'VAT', 'Tax', 'Total (BDT)', 'Status'],
            data: projectExpenses.take(15).map((e) => [
              DateFormatter.formatShort(e.date),
              e.categoryName,
              e.employeeName,
              e.baseCost.toStringAsFixed(0),
              e.vatAmount.toStringAsFixed(0),
              e.taxAmount.toStringAsFixed(0),
              e.totalCost.toStringAsFixed(0),
              e.status.displayName,
            ]).toList(),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfKpiCard(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  /// Generates formatted Excel XML Spreadsheet (.xls)
  static String generateExcelXml({
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0"?>');
    buffer.writeln('<?mso-application progid="Excel.Sheet"?>');
    buffer.writeln('<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"');
    buffer.writeln(' xmlns:o="urn:schemas-microsoft-com:office:office"');
    buffer.writeln(' xmlns:x="urn:schemas-microsoft-com:office:excel"');
    buffer.writeln(' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"');
    buffer.writeln(' xmlns:html="http://www.w3.org/TR/REC-html40">');

    buffer.writeln(' <Styles>');
    buffer.writeln('  <Style ss:ID="Default" ss:Name="Normal"><Alignment ss:Vertical="Center"/></Style>');
    buffer.writeln('  <Style ss:ID="HeaderStyle"><Font ss:Bold="1" ss:Color="#FFFFFF"/><Interior ss:Color="#4338CA" ss:Pattern="Solid"/></Style>');
    buffer.writeln('  <Style ss:ID="TitleStyle"><Font ss:Size="14" ss:Bold="1" ss:Color="#1E1B4B"/></Style>');
    buffer.writeln(' </Styles>');

    buffer.writeln(' <Worksheet ss:Name="Export">');
    buffer.writeln('  <Table>');

    // Title Row
    buffer.writeln('   <Row ss:Height="24">');
    buffer.writeln('    <Cell ss:StyleID="TitleStyle"><Data ss:Type="String">$title</Data></Cell>');
    buffer.writeln('   </Row>');
    buffer.writeln('   <Row ss:Height="10"/>');

    // Headers
    buffer.writeln('   <Row ss:Height="20">');
    for (final h in headers) {
      buffer.writeln('    <Cell ss:StyleID="HeaderStyle"><Data ss:Type="String">$h</Data></Cell>');
    }
    buffer.writeln('   </Row>');

    // Rows
    for (final r in rows) {
      buffer.writeln('   <Row>');
      for (final cell in r) {
        final val = cell?.toString() ?? '';
        final isNum = double.tryParse(val.replaceAll(',', '').replaceAll('BDT', '').trim()) != null;
        if (isNum) {
          final cleanNum = double.parse(val.replaceAll(',', '').replaceAll('BDT', '').trim());
          buffer.writeln('    <Cell><Data ss:Type="Number">$cleanNum</Data></Cell>');
        } else {
          buffer.writeln('    <Cell><Data ss:Type="String">${val.replaceAll('&', '&amp;').replaceAll('<', '&lt;')}</Data></Cell>');
        }
      }
      buffer.writeln('   </Row>');
    }

    buffer.writeln('  </Table>');
    buffer.writeln(' </Worksheet>');
    buffer.writeln('</Workbook>');

    return buffer.toString();
  }

  /// Generates formatted Word Document (.doc) with rich HTML styling
  static String generateWordDoc({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html>');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="utf-8">');
    buffer.writeln('<title>$title</title>');
    buffer.writeln('<style>');
    buffer.writeln('body { font-family: "Calibri", "Segoe UI", sans-serif; margin: 40px; color: #1E293B; }');
    buffer.writeln('h1 { color: #3730A3; font-size: 22px; margin-bottom: 4px; }');
    buffer.writeln('p.subtitle { color: #64748B; font-size: 13px; margin-top: 0; margin-bottom: 24px; }');
    buffer.writeln('table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 12px; }');
    buffer.writeln('th { background-color: #4F46E5; color: #FFFFFF; font-weight: bold; padding: 10px 8px; text-align: left; border: 1px solid #4338CA; }');
    buffer.writeln('td { padding: 8px; border: 1px solid #E2E8F0; }');
    buffer.writeln('tr:nth-child(even) { background-color: #F8FAFC; }');
    buffer.writeln('.footer { margin-top: 30px; font-size: 10px; color: #94A3B8; border-top: 1px solid #E2E8F0; padding-top: 8px; }');
    buffer.writeln('</style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    buffer.writeln('<h1>$title</h1>');
    buffer.writeln('<p class="subtitle">$subtitle &bull; Generated: ${DateFormatter.formatShort(DateTime.now())}</p>');

    buffer.writeln('<table>');
    buffer.writeln('<thead><tr>');
    for (final h in headers) {
      buffer.writeln('<th>$h</th>');
    }
    buffer.writeln('</tr></thead>');

    buffer.writeln('<tbody>');
    for (final r in rows) {
      buffer.writeln('<tr>');
      for (final cell in r) {
        buffer.writeln('<td>${cell?.toString() ?? ''}</td>');
      }
      buffer.writeln('</tr>');
    }
    buffer.writeln('</tbody>');
    buffer.writeln('</table>');

    buffer.writeln('<div class="footer">GW Project Enterprise Management &bull; Confidential Financial Report</div>');
    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  /// Generates Excel XML Spreadsheet for Financial Overview
  static String generateFinancialOverviewExcel(List<ProjectModel> projects, List<ExpenseModel> expenses) {
    final headers = [
      'Project ID',
      'Project Name',
      'Client',
      'Status',
      'Gross Value (BDT)',
      'Cost Incurred (BDT)',
      'Projected Remaining (BDT)',
      'Projected Final Cost (BDT)',
      'Projected Profit (BDT)',
      'Margin (%)',
    ];
    final rows = <List<dynamic>>[];
    for (final p in projects) {
      final projectExpenses = expenses.where((e) => e.projectId == p.id && e.status == ExpenseStatus.approved).toList();
      final directCost = projectExpenses.fold<double>(0.0, (sum, e) => sum + e.totalCost);
      final officeBenefit = directCost * p.officeBenefitRate;
      final totalCostIncurred = directCost + officeBenefit;
      final projectedFinalCost = totalCostIncurred + p.estimatedRemainingCost;
      final projectedProfit = p.grossProjectValue - projectedFinalCost;
      final projectedMargin = p.grossProjectValue > 0 ? (projectedProfit / p.grossProjectValue) * 100 : 0.0;

      rows.add([
        p.projectId,
        p.name,
        p.client,
        p.status.displayName,
        p.grossProjectValue.toStringAsFixed(2),
        totalCostIncurred.toStringAsFixed(2),
        p.estimatedRemainingCost.toStringAsFixed(2),
        projectedFinalCost.toStringAsFixed(2),
        projectedProfit.toStringAsFixed(2),
        '${projectedMargin.toStringAsFixed(1)}%',
      ]);
    }
    return generateExcelXml(
      title: 'GW Project - Financial Overview Portfolio Report',
      headers: headers,
      rows: rows,
    );
  }

  /// Generates Excel XML Spreadsheet for a Single Project Detail
  static String generateProjectDetailExcel(ProjectModel project, List<ExpenseModel> projectExpenses) {
    final headers = ['Cost Category', 'Budget (BDT)', 'Actual Incurred (BDT)', 'Remaining (BDT)', 'Variance (%)', 'Status'];
    final rows = <List<dynamic>>[];

    final categories = ['Equipment', 'Transportation', 'Food', 'Accommodation', 'Office Cost'];
    double totalBudget = 0.0;
    double totalActual = 0.0;

    for (final cat in categories) {
      final budget = project.categoryBudgets[cat.toLowerCase().replaceAll(' ', '')] ?? 0.0;
      final actual = projectExpenses
          .where((e) => e.status == ExpenseStatus.approved && e.categoryName.toLowerCase().contains(cat.toLowerCase().split(' ').first))
          .fold<double>(0.0, (sum, e) => sum + e.totalCost);
      final remaining = budget - actual;
      final variance = budget > 0 ? ((actual - budget) / budget) * 100 : 0.0;
      final status = actual > budget ? 'OVER BUDGET' : (actual >= budget * 0.8 ? 'APPROACHING' : 'ON TRACK');

      totalBudget += budget;
      totalActual += actual;

      rows.add([
        cat,
        budget.toStringAsFixed(2),
        actual.toStringAsFixed(2),
        remaining.toStringAsFixed(2),
        '${variance.toStringAsFixed(1)}%',
        status,
      ]);
    }

    final obBudget = project.categoryBudgets['officebenefit'] ?? (totalBudget * project.officeBenefitRate);
    final obActual = totalActual * project.officeBenefitRate;
    final obRemaining = obBudget - obActual;
    final obVariance = obBudget > 0 ? ((obActual - obBudget) / obBudget) * 100 : 0.0;
    rows.add([
      'Office Benefit (${(project.officeBenefitRate * 100).toInt()}%)',
      obBudget.toStringAsFixed(2),
      obActual.toStringAsFixed(2),
      obRemaining.toStringAsFixed(2),
      '${obVariance.toStringAsFixed(1)}%',
      'CALCULATED',
    ]);

    final grandBudget = totalBudget + obBudget;
    final grandActual = totalActual + obActual;
    final grandRemaining = grandBudget - grandActual;
    rows.add([
      'TOTAL BUDGET',
      grandBudget.toStringAsFixed(2),
      grandActual.toStringAsFixed(2),
      grandRemaining.toStringAsFixed(2),
      '${grandBudget > 0 ? (((grandActual - grandBudget) / grandBudget) * 100).toStringAsFixed(1) : '0.0'}%',
      grandActual > grandBudget ? 'OVER BUDGET' : 'ON TRACK',
    ]);

    return generateExcelXml(
      title: 'Project Budget & Expense Report: ${project.name} (${project.projectId})',
      headers: headers,
      rows: rows,
    );
  }

  /// Generates Word Document (.doc) for Financial Overview
  static String generateFinancialOverviewWord(List<ProjectModel> projects, List<ExpenseModel> expenses) {
    final headers = [
      'Project ID',
      'Project Name',
      'Client',
      'Status',
      'Contract Value (BDT)',
      'Incurred Cost (BDT)',
      'Projected Profit (BDT)',
      'Margin',
    ];
    final rows = <List<dynamic>>[];
    for (final p in projects) {
      final projectExpenses = expenses.where((e) => e.projectId == p.id && e.status == ExpenseStatus.approved).toList();
      final directCost = projectExpenses.fold<double>(0.0, (sum, e) => sum + e.totalCost);
      final officeBenefit = directCost * p.officeBenefitRate;
      final totalCostIncurred = directCost + officeBenefit;
      final projectedFinalCost = totalCostIncurred + p.estimatedRemainingCost;
      final projectedProfit = p.grossProjectValue - projectedFinalCost;
      final projectedMargin = p.grossProjectValue > 0 ? (projectedProfit / p.grossProjectValue) * 100 : 0.0;

      rows.add([
        p.projectId,
        p.name,
        p.client,
        p.status.displayName,
        p.grossProjectValue.toStringAsFixed(2),
        totalCostIncurred.toStringAsFixed(2),
        projectedProfit.toStringAsFixed(2),
        '${projectedMargin.toStringAsFixed(1)}%',
      ]);
    }

    return generateWordDoc(
      title: 'Financial Overview & Portfolio Summary',
      subtitle: '${projects.length} Active & Completed Projects',
      headers: headers,
      rows: rows,
    );
  }

  /// Generates Word Document (.doc) for a Single Project Detail
  static String generateProjectDetailWord(ProjectModel project, List<ExpenseModel> projectExpenses) {
    final headers = ['Category', 'Budget (BDT)', 'Actual Incurred (BDT)', 'Variance (%)', 'Status'];
    final rows = <List<dynamic>>[];

    final categories = ['Equipment', 'Transportation', 'Food', 'Accommodation', 'Office Cost'];
    double totalBudget = 0.0;
    double totalActual = 0.0;

    for (final cat in categories) {
      final budget = project.categoryBudgets[cat.toLowerCase().replaceAll(' ', '')] ?? 0.0;
      final actual = projectExpenses
          .where((e) => e.status == ExpenseStatus.approved && e.categoryName.toLowerCase().contains(cat.toLowerCase().split(' ').first))
          .fold<double>(0.0, (sum, e) => sum + e.totalCost);
      final variance = budget > 0 ? ((actual - budget) / budget) * 100 : 0.0;
      final status = actual > budget ? 'OVER BUDGET' : (actual >= budget * 0.8 ? 'APPROACHING' : 'ON TRACK');

      totalBudget += budget;
      totalActual += actual;

      rows.add([
        cat,
        budget.toStringAsFixed(2),
        actual.toStringAsFixed(2),
        '${variance.toStringAsFixed(1)}%',
        status,
      ]);
    }

    final obBudget = project.categoryBudgets['officebenefit'] ?? (totalBudget * project.officeBenefitRate);
    final obActual = totalActual * project.officeBenefitRate;
    final obVariance = obBudget > 0 ? ((obActual - obBudget) / obBudget) * 100 : 0.0;
    rows.add([
      'Office Benefit (${(project.officeBenefitRate * 100).toInt()}%)',
      obBudget.toStringAsFixed(2),
      obActual.toStringAsFixed(2),
      '${obVariance.toStringAsFixed(1)}%',
      'CALCULATED',
    ]);

    final grandBudget = totalBudget + obBudget;
    final grandActual = totalActual + obActual;
    rows.add([
      'TOTAL BUDGET',
      grandBudget.toStringAsFixed(2),
      grandActual.toStringAsFixed(2),
      '${grandBudget > 0 ? (((grandActual - grandBudget) / grandBudget) * 100).toStringAsFixed(1) : '0.0'}%',
      grandActual > grandBudget ? 'OVER BUDGET' : 'ON TRACK',
    ]);

    return generateWordDoc(
      title: 'Project Audit Report: ${project.name}',
      subtitle: 'Project ID: ${project.projectId} | Client: ${project.client}',
      headers: headers,
      rows: rows,
    );
  }

  /// Saves bytes to temp storage and invokes native system share (Gmail, Google Drive, WhatsApp, etc.)
  static Future<void> saveAndShare({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? subject,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType, name: fileName)],
        subject: subject,
        text: subject ?? 'GW Project Export: $fileName',
      ),
    );
  }

  /// Preview or Print PDF document
  static Future<void> previewOrPrintPdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    await saveAndShare(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'application/pdf',
      subject: 'Document Preview: $fileName',
    );
  }
}
