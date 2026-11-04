import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/core/services/cache_retention_service.dart';
import 'package:expense_tracking_prd/models/attendance_model.dart';
import 'package:expense_tracking_prd/models/expense_model.dart';
import 'package:expense_tracking_prd/models/leave_model.dart';
import 'package:expense_tracking_prd/models/project_model.dart';
import 'package:expense_tracking_prd/state/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 1: Attendance Work Modes & Early Departure', () {
    test('AttendanceRecordModel parses and identifies office, onField, and homeOffice modes', () {
      final officeRecord = AttendanceRecordModel(
        id: 'att-1',
        userId: 'emp-101',
        userName: 'Engr. Rafiq',
        date: '2026-11-01',
        sessionType: 'morning',
        loginTime: DateTime(2026, 11, 1, 9, 0),
        createdAt: DateTime(2026, 11, 1, 9, 0),
        notes: 'Standard morning check-in',
      );

      final fieldRecord = AttendanceRecordModel(
        id: 'att-2',
        userId: 'emp-101',
        userName: 'Engr. Rafiq',
        date: '2026-11-01',
        sessionType: 'morning',
        loginTime: DateTime(2026, 11, 1, 9, 0),
        createdAt: DateTime(2026, 11, 1, 9, 0),
        notes: '[Work Mode: Field] Dhaka Bypass Project Site',
      );

      final homeRecord = AttendanceRecordModel(
        id: 'att-3',
        userId: 'emp-101',
        userName: 'Engr. Rafiq',
        date: '2026-11-01',
        sessionType: 'morning',
        loginTime: DateTime(2026, 11, 1, 9, 0),
        createdAt: DateTime(2026, 11, 1, 9, 0),
        notes: '[Work Mode: Home Office] Approved remote CAD drafting',
      );

      expect(officeRecord.workModeLabel, 'Office');
      expect(officeRecord.isFieldDuty, isFalse);
      expect(officeRecord.isHomeOffice, isFalse);

      expect(fieldRecord.workModeLabel, 'On Field');
      expect(fieldRecord.isFieldDuty, isTrue);

      expect(homeRecord.workModeLabel, 'Home Office');
      expect(homeRecord.isHomeOffice, isTrue);
    });

    test('AttendanceRecordModel correctly detects early departure from check-out notes', () {
      final record = AttendanceRecordModel(
        id: 'att-early-1',
        userId: 'emp-102',
        userName: 'Sarah Ahmed',
        date: '2026-11-01',
        sessionType: 'afternoon',
        loginTime: DateTime(2026, 11, 1, 14, 30),
        createdAt: DateTime(2026, 11, 1, 14, 30),
        notes: '[Early Departure: Medical emergency doctor appointment]',
      );

      expect(record.isEarlyDeparture, isTrue);
    });
  });

  group('Feature 2: Leave Request & Management System', () {
    test('LeaveRecordModel tracks days, display type, and approval state', () {
      const leave = LeaveRecordModel(
        id: 'leave-100',
        userId: 'emp-101',
        userName: 'Engr. Rafiq',
        leaveType: 'casual',
        startDate: '2026-11-10',
        endDate: '2026-11-12',
        reason: 'Family event out of town',
        isApproved: false,
      );

      expect(leave.totalDays, 3);
      expect(leave.typeDisplayName, 'Casual Leave');
      expect(leave.isApproved, isFalse);
      expect(leave.statusText, 'Pending approval');
      expect(leave.isPaid, isTrue);
    });

    test('LeaveRecordModel deserializes from JSON correctly', () {
      final json = {
        'id': 'leave-200',
        'userId': 'emp-105',
        'userName': 'Kazi Monir',
        'leaveType': 'sick',
        'startDate': '2026-11-15',
        'endDate': '2026-11-16',
        'reason': 'Fever and rest',
        'isApproved': true,
      };

      final record = LeaveRecordModel.fromJson(json);
      expect(record.id, 'leave-200');
      expect(record.typeDisplayName, 'Medical / Sick Leave');
      expect(record.totalDays, 2);
      expect(record.isApproved, isTrue);
      expect(record.statusText, 'Approved');
    });
  });

  group('Feature 3: VAT & Tax Segmentation in Expenses', () {
    test('ExpenseModel computes segmented cost: Base + VAT + Tax = Total Cost', () {
      final expense = ExpenseModel(
        id: 'exp-tax-1',
        projectId: 'proj-1',
        projectName: 'Padma Bridge Access Road',
        categoryId: 'cat-eq',
        categoryName: 'Equipment & Heavy Machinery',
        categoryIcon: 'build',
        amount: 115000.0,
        baseCost: 100000.0,
        vatRate: 10.0,
        vatAmount: 10000.0,
        taxRate: 5.0,
        taxAmount: 5000.0,
        date: DateTime(2026, 11, 1),
        employeeId: 'emp-1',
        employeeName: 'Site Supervisor',
        note: 'Site equipment calibration',
        createdAt: DateTime(2026, 11, 1),
        status: ExpenseStatus.pending,
      );

      expect(expense.baseCost, 100000.0);
      expect(expense.vatRate, 10.0);
      expect(expense.vatAmount, 10000.0);
      expect(expense.taxRate, 5.0);
      expect(expense.taxAmount, 5000.0);
      expect(expense.hasVat, isTrue);
      expect(expense.hasTax, isTrue);
      expect(expense.totalCost, 115000.0);
      expect(expense.totalCost, expense.baseCost + expense.vatAmount + expense.taxAmount);

      final json = expense.toJson();
      expect(json['base_cost'], 100000.0);
      expect(json['vat_rate'], 10.0);
      expect(json['vat_amount'], 10000.0);
      expect(json['tax_rate'], 5.0);
      expect(json['tax_amount'], 5000.0);
      expect(json['total_cost'], 115000.0);
    });
  });

  group('Feature 4: Multi-format Project Exporting (PDF, Excel, Word, CSV)', () {
    final mockProject = ProjectModel(
      id: 'proj-export-1',
      projectId: 'PRJ-2026-001',
      name: 'Gulshan Elevated Highway Survey',
      description: 'Comprehensive topographical survey',
      client: 'Dhaka City Corporation',
      grossProjectValue: 5000000.0,
      expectedNetRevenue: 4500000.0,
      amountReceivable: 5000000.0,
      budget: 4000000.0,
      status: ProjectStatus.ongoing,
      assignmentType: AssignmentType.government,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      teamMemberIds: const ['emp-1'],
    );

    final List<ExpenseModel> mockExpenses = [
      ExpenseModel(
        id: 'exp-1',
        projectId: 'proj-export-1',
        projectName: 'Gulshan Elevated Highway Survey',
        categoryId: 'equipment',
        categoryName: 'Equipment',
        categoryIcon: 'build',
        amount: 55000.0,
        baseCost: 50000.0,
        vatRate: 10.0,
        vatAmount: 5000.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        date: DateTime(2026, 10, 15),
        employeeId: 'emp-1',
        employeeName: 'Chief Surveyor',
        note: 'Survey equipment',
        createdAt: DateTime(2026, 10, 15),
        status: ExpenseStatus.approved,
      ),
    ];

    test('generateFinancialOverviewCsv produces valid CSV data', () {
      final csv = ExportService.generateFinancialOverviewCsv([mockProject], mockExpenses);
      expect(csv, contains('PRJ-2026-001'));
      expect(csv, contains('Gulshan Elevated Highway Survey'));
      expect(csv, contains('Gross Contract Value (BDT)'));
    });

    test('generateExcelXml produces Microsoft Excel XML Spreadsheet', () {
      final xml = ExportService.generateFinancialOverviewExcel([mockProject], mockExpenses);
      expect(xml, contains('<?xml version="1.0"?>'));
      expect(xml, contains('progid="Excel.Sheet"'));
      expect(xml, contains('<Worksheet ss:Name="Export">'));
      expect(xml, contains('PRJ-2026-001'));
    });

    test('generateWordDoc produces HTML-compatible Word document', () {
      final doc = ExportService.generateFinancialOverviewWord([mockProject], mockExpenses);
      expect(doc, contains('<!DOCTYPE html>'));
      expect(doc, contains('Financial Overview & Portfolio Summary'));
      expect(doc, contains('GW Project Enterprise Management'));
      expect(doc, contains('PRJ-2026-001'));
    });

    test('generateFinancialOverviewPdf generates non-empty binary PDF stream', () async {
      final pdfBytes = await ExportService.generateFinancialOverviewPdf([mockProject], mockExpenses);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });
  });

  group('Feature 5: Cache Retention & Document Purge Policy', () {
    test('CacheRetentionService retention options and labels', () {
      expect(CacheRetentionService.retentionOptions, contains(7));
      expect(CacheRetentionService.retentionOptions, contains(14));
      expect(CacheRetentionService.retentionOptions, contains(30));
      expect(CacheRetentionService.retentionOptions, contains(-1));

      expect(CacheRetentionService.getRetentionLabel(7), '7 Days');
      expect(CacheRetentionService.getRetentionLabel(14), '14 Days');
      expect(CacheRetentionService.getRetentionLabel(30), '30 Days (Recommended)');
      expect(CacheRetentionService.getRetentionLabel(-1), 'Never (Manual Only)');
    });
  });
}
