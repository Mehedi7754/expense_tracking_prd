class HistoricalProjectBenchmark {
  final String id;
  final String projectName;
  final String projectType; // Survey, Feasibility, IT/Engineering, Advisory, Impact Assessment
  final int durationMonths;
  final int staffCount;
  final int locationsCount;
  final int respondentsCount;
  final String travelIntensity; // Low, Medium, High
  final double totalActualCost;
  final double transportCostPercentage;
  final double accommodationCostPercentage;
  final double foodCostPercentage;
  final double equipmentCostPercentage;
  final double officeCostPercentage;
  final double personnelCostPercentage;
  final double averageProfitMargin;

  const HistoricalProjectBenchmark({
    required this.id,
    required this.projectName,
    required this.projectType,
    required this.durationMonths,
    required this.staffCount,
    required this.locationsCount,
    required this.respondentsCount,
    required this.travelIntensity,
    required this.totalActualCost,
    required this.transportCostPercentage,
    required this.accommodationCostPercentage,
    required this.foodCostPercentage,
    required this.equipmentCostPercentage,
    required this.officeCostPercentage,
    required this.personnelCostPercentage,
    required this.averageProfitMargin,
  });

  factory HistoricalProjectBenchmark.fromJson(Map<String, dynamic> json) {
    return HistoricalProjectBenchmark(
      id: (json['id'] ?? '').toString(),
      projectName: (json['project_name'] ?? json['projectName'] ?? '').toString(),
      projectType: (json['project_type'] ?? json['projectType'] ?? '').toString(),
      durationMonths: (json['duration_months'] ?? json['durationMonths'] as num?)?.toInt() ?? 1,
      staffCount: (json['staff_count'] ?? json['staffCount'] as num?)?.toInt() ?? 1,
      locationsCount: (json['locations_count'] ?? json['locationsCount'] as num?)?.toInt() ?? 1,
      respondentsCount: (json['respondents_count'] ?? json['respondentsCount'] as num?)?.toInt() ?? 0,
      travelIntensity: (json['travel_intensity'] ?? json['travelIntensity'] ?? 'Medium').toString(),
      totalActualCost: (json['total_actual_cost'] ?? json['totalActualCost'] as num?)?.toDouble() ?? 0.0,
      transportCostPercentage: (json['transport_cost_pct'] ?? json['transportCostPercentage'] as num?)?.toDouble() ?? 0.0,
      accommodationCostPercentage: (json['accommodation_cost_pct'] ?? json['accommodationCostPercentage'] as num?)?.toDouble() ?? 0.0,
      foodCostPercentage: (json['food_cost_pct'] ?? json['foodCostPercentage'] as num?)?.toDouble() ?? 0.0,
      equipmentCostPercentage: (json['equipment_cost_pct'] ?? json['equipmentCostPercentage'] as num?)?.toDouble() ?? 0.0,
      officeCostPercentage: (json['office_cost_pct'] ?? json['officeCostPercentage'] as num?)?.toDouble() ?? 0.0,
      personnelCostPercentage: (json['personnel_cost_pct'] ?? json['personnelCostPercentage'] as num?)?.toDouble() ?? 0.0,
      averageProfitMargin: (json['average_profit_margin'] ?? json['averageProfitMargin'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_name': projectName,
      'project_type': projectType,
      'duration_months': durationMonths,
      'staff_count': staffCount,
      'locations_count': locationsCount,
      'respondents_count': respondentsCount,
      'travel_intensity': travelIntensity,
      'total_actual_cost': totalActualCost,
      'transport_cost_percentage': transportCostPercentage,
      'accommodation_cost_percentage': accommodationCostPercentage,
      'food_cost_percentage': foodCostPercentage,
      'equipment_cost_percentage': equipmentCostPercentage,
      'office_cost_percentage': officeCostPercentage,
      'personnel_cost_percentage': personnelCostPercentage,
      'average_profit_margin': averageProfitMargin,
    };
  }
}

class EstimationResult {
  final double estimatedCost;
  final double recommendedContingency;
  final double estimatedTotalBudget;
  final double proposedFee;
  final double estimatedProfit;
  final double estimatedProfitMargin;
  final Map<String, double> categoryEstimates;
  final List<String> referenceProjects;

  const EstimationResult({
    required this.estimatedCost,
    required this.recommendedContingency,
    required this.estimatedTotalBudget,
    required this.proposedFee,
    required this.estimatedProfit,
    required this.estimatedProfitMargin,
    required this.categoryEstimates,
    required this.referenceProjects,
  });

  factory EstimationResult.fromJson(Map<String, dynamic> json) {
    Map<String, double> parseCategoryEstimates(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0));
      }
      return const {};
    }

    List<String> parseRefProjects(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return const [];
    }

    return EstimationResult(
      estimatedCost: (json['estimated_cost'] ?? json['estimatedCost'] as num?)?.toDouble() ?? 0.0,
      recommendedContingency: (json['recommended_contingency'] ?? json['recommendedContingency'] as num?)?.toDouble() ?? 0.0,
      estimatedTotalBudget: (json['estimated_total_budget'] ?? json['estimatedTotalBudget'] as num?)?.toDouble() ?? 0.0,
      proposedFee: (json['proposed_fee'] ?? json['proposedFee'] as num?)?.toDouble() ?? 0.0,
      estimatedProfit: (json['estimated_profit'] ?? json['estimatedProfit'] as num?)?.toDouble() ?? 0.0,
      estimatedProfitMargin: (json['estimated_profit_margin'] ?? json['estimatedProfitMargin'] as num?)?.toDouble() ?? 0.0,
      categoryEstimates: parseCategoryEstimates(json['category_estimates'] ?? json['categoryEstimates']),
      referenceProjects: parseRefProjects(json['reference_projects'] ?? json['referenceProjects']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'estimated_cost': estimatedCost,
      'recommended_contingency': recommendedContingency,
      'estimated_total_budget': estimatedTotalBudget,
      'proposed_fee': proposedFee,
      'estimated_profit': estimatedProfit,
      'estimated_profit_margin': estimatedProfitMargin,
      'category_estimates': categoryEstimates,
      'reference_projects': referenceProjects,
    };
  }
}
