import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/core/utils/date_formatter.dart';

void main() {
  test('project dates use unambiguous day/month/year format', () {
    expect(
      DateFormatter.formatDayMonthYear(DateTime(2026, 11, 2)),
      '02/11/2026',
    );
  });
}
