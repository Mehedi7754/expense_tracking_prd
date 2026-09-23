import '../models/expense_model.dart';
import '../models/project_model.dart';

class ExportService {
  ExportService._();

  /// Generates CSV format for Projects Portfolio (PRD Section 3 & 25)
  static String exportProjectsToCsv(List<ProjectModel> projects, List<ExpenseModel> expenses) {
    final buffer = StringBuffer();
    // Headers
    buffer.writeln('Project ID,Project Name,Client,Client Type,Assignment Type,Status,Gross Contract Value (BDT),Cost Incurred (BDT),Projected Remaining (BDT),Projected Final Cost (BDT),Projected Profit (BDT),Projected Margin (%),Amount Received (BDT),Amount Receivable (BDT)');

    for (final p in projects) {
      final projectExpenses = expenses.where((e) => e.projectId == p.id).toList();
      final directCost = projectExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
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

  /// Generates CSV format for Expenses & Receipts (PRD Section 6, 10, 25)
  static String exportExpensesToCsv(List<ExpenseModel> expenses) {
    final buffer = StringBuffer();
    buffer.writeln('Expense ID,Date,Project Name,Category,Amount (BDT),Office Benefit 30% (BDT),Total Cost (BDT),Entered By,Receipt Available,Receipt Status,Approval Status,Justification Status,Purpose/Note');

    for (final e in expenses) {
      buffer.writeln(
        '"${e.id}",'
        '"${e.date.toIso8601String().split('T').first}",'
        '"${e.projectName.replaceAll('"', '""')}",'
        '"${e.categoryName}",'
        '${e.amount.toStringAsFixed(2)},'
        '${e.officeBenefitAmount.toStringAsFixed(2)},'
        '${e.totalWithBenefit.toStringAsFixed(2)},'
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

  /// Generates CSV format for Budget vs Actual (PRD Section 14 & 25)
  static String exportBudgetVsActualToCsv(ProjectModel project, List<ExpenseModel> projectExpenses) {
    final buffer = StringBuffer();
    buffer.writeln('Project: ${project.name} (${project.projectId})');
    buffer.writeln('Contract Value: BDT ${project.grossProjectValue.toStringAsFixed(2)}');
    buffer.writeln('');
    buffer.writeln('Cost Category,Budget (BDT),Actual Incurred (BDT),Remaining (BDT),Variance (%),Status');

    final categories = ['Equipment', 'Transportation', 'Food', 'Accommodation', 'Office Cost'];
    double totalBudget = 0.0;
    double totalActual = 0.0;

    for (final cat in categories) {
      final budget = project.categoryBudgets[cat.toLowerCase().replaceAll(' ', '')] ?? 0.0;
      final actual = projectExpenses
          .where((e) => e.categoryName.toLowerCase().contains(cat.toLowerCase().split(' ').first))
          .fold<double>(0.0, (sum, e) => sum + e.amount);

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

    // Office Benefit 30%
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

    return buffer.toString();
  }
}
