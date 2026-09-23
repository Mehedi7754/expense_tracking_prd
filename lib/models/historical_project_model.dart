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
}
