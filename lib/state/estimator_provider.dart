import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/historical_project_model.dart';

class EstimatorState {
  final List<HistoricalProjectBenchmark> benchmarks;
  final EstimationResult? lastResult;

  const EstimatorState({
    required this.benchmarks,
    this.lastResult,
  });

  EstimatorState copyWith({
    List<HistoricalProjectBenchmark>? benchmarks,
    EstimationResult? lastResult,
  }) {
    return EstimatorState(
      benchmarks: benchmarks ?? this.benchmarks,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class EstimatorNotifier extends Notifier<EstimatorState> {
  static const List<HistoricalProjectBenchmark> _defaultBenchmarks = [
    HistoricalProjectBenchmark(
      id: 'bench_01',
      projectName: 'Enterprise Cloud ERP Migration 2024',
      projectType: 'Cloud & ERP',
      durationMonths: 6,
      staffCount: 18,
      locationsCount: 5,
      respondentsCount: 500,
      travelIntensity: 'Low',
      totalActualCost: 1850000.0,
      transportCostPercentage: 12.0,
      accommodationCostPercentage: 14.0,
      foodCostPercentage: 10.0,
      equipmentCostPercentage: 35.0,
      officeCostPercentage: 14.0,
      personnelCostPercentage: 15.0,
      averageProfitMargin: 38.0,
    ),
    HistoricalProjectBenchmark(
      id: 'bench_02',
      projectName: 'Fintech Mobile Banking App V1 2024',
      projectType: 'Fintech Mobile',
      durationMonths: 4,
      staffCount: 8,
      locationsCount: 2,
      respondentsCount: 100,
      travelIntensity: 'Low',
      totalActualCost: 920000.0,
      transportCostPercentage: 10.0,
      accommodationCostPercentage: 12.0,
      foodCostPercentage: 12.0,
      equipmentCostPercentage: 40.0,
      officeCostPercentage: 12.0,
      personnelCostPercentage: 14.0,
      averageProfitMargin: 42.0,
    ),
    HistoricalProjectBenchmark(
      id: 'bench_03',
      projectName: 'AI Telehealth Diagnostic Platform 2025',
      projectType: 'AI & HealthTech',
      durationMonths: 8,
      staffCount: 14,
      locationsCount: 4,
      respondentsCount: 300,
      travelIntensity: 'Low',
      totalActualCost: 2200000.0,
      transportCostPercentage: 20.0,
      accommodationCostPercentage: 14.0,
      foodCostPercentage: 14.0,
      equipmentCostPercentage: 24.0,
      officeCostPercentage: 13.0,
      personnelCostPercentage: 15.0,
      averageProfitMargin: 35.0,
    ),
    HistoricalProjectBenchmark(
      id: 'bench_04',
      projectName: 'BRAC Microfinance Client Impact Assessment 2025',
      projectType: 'Impact Assessment',
      durationMonths: 3,
      staffCount: 10,
      locationsCount: 12,
      respondentsCount: 4000,
      travelIntensity: 'High',
      totalActualCost: 780000.0,
      transportCostPercentage: 30.0,
      accommodationCostPercentage: 25.0,
      foodCostPercentage: 18.0,
      equipmentCostPercentage: 8.0,
      officeCostPercentage: 9.0,
      personnelCostPercentage: 10.0,
      averageProfitMargin: 40.0,
    ),
  ];

  @override
  EstimatorState build() => const EstimatorState(benchmarks: _defaultBenchmarks);

  EstimationResult calculateEstimate({
    required String projectType,
    required int durationMonths,
    required int staffCount,
    required int locationsCount,
    required int respondentsCount,
    required String travelIntensity,
    required double proposedFee,
  }) {
    // Travel intensity multiplier
    double travelMultiplier = 1.0;
    if (travelIntensity == 'High') travelMultiplier = 1.35;
    if (travelIntensity == 'Low') travelMultiplier = 0.75;

    // Unit-based base costing
    // 1. Staff per diem & local expenses: ~৳1,200/day * 22 field days/month
    final staffFieldCost = staffCount * durationMonths * 22 * 1200.0 * travelMultiplier;

    // 2. Field logistics & transportation per location
    final locationTransportCost = locationsCount * 15000.0 * travelMultiplier;

    // 3. Survey data collection instrument & survey enumerator cost per respondent
    final respondentDataCost = respondentsCount * 65.0;

    // 4. Equipment rental / depreciation
    final equipmentCost = (staffCount * 3500.0) + (durationMonths * 8000.0);

    // 5. Office & management coordination
    final officeCost = durationMonths * 35000.0;

    final baseCost = staffFieldCost + locationTransportCost + respondentDataCost + equipmentCost + officeCost;

    // Recommended contingency (10% - 15% depending on travel and duration)
    final contingencyRate = (travelIntensity == 'High' || durationMonths > 6) ? 0.12 : 0.08;
    final recommendedContingency = baseCost * contingencyRate;
    final totalEstimatedBudget = baseCost + recommendedContingency;

    final profit = proposedFee - totalEstimatedBudget;
    final profitMargin = proposedFee > 0 ? (profit / proposedFee) * 100 : 0.0;

    // Category distribution estimates
    final categoryEstimates = {
      'Transportation': (staffFieldCost * 0.35) + locationTransportCost,
      'Accommodation': staffFieldCost * 0.35,
      'Food': staffFieldCost * 0.30,
      'Equipment': equipmentCost,
      'Office Cost': officeCost,
      'Field Enumeration / Other': respondentDataCost,
    };

    final matchingProjects = state.benchmarks
        .where((b) => b.projectType == projectType || b.travelIntensity == travelIntensity)
        .map((b) => b.projectName)
        .toList();

    final result = EstimationResult(
      estimatedCost: baseCost,
      recommendedContingency: recommendedContingency,
      estimatedTotalBudget: totalEstimatedBudget,
      proposedFee: proposedFee,
      estimatedProfit: profit,
      estimatedProfitMargin: profitMargin,
      categoryEstimates: categoryEstimates,
      referenceProjects: matchingProjects.isNotEmpty
          ? matchingProjects
          : state.benchmarks.map((b) => b.projectName).take(2).toList(),
    );

    state = state.copyWith(lastResult: result);
    return result;
  }
}

final estimatorProvider =
    NotifierProvider<EstimatorNotifier, EstimatorState>(EstimatorNotifier.new);
