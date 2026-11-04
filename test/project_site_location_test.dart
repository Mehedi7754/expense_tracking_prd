import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/models/project_model.dart';

void main() {
  test('project site pin survives API and cache serialization', () {
    final project = ProjectModel.fromJson({
      'id': 'project-1',
      'name': 'Field survey',
      'siteLatitude': 23.8103,
      'siteLongitude': 90.4125,
    });

    expect(project.siteLatitude, 23.8103);
    expect(project.siteLongitude, 90.4125);
    expect(project.toJson(forApi: true)['siteLatitude'], 23.8103);
    final cached = ProjectModel.fromJson(project.toJson());
    expect(cached.siteLatitude, 23.8103);
    expect(cached.siteLongitude, 90.4125);
    expect(cached.copyWith(clearSiteLocation: true).siteLatitude, isNull);

    final legacyApiResponse = ProjectModel.fromJson({
      'id': 'project-1',
      'name': 'Field survey',
      'siteLatitude': null,
      'siteLongitude': null,
      'categoryBudgets': project.toJson(forApi: true)['category_budgets'],
    });
    expect(legacyApiResponse.siteLatitude, 23.8103);
    expect(legacyApiResponse.siteLongitude, 90.4125);
  });
}
