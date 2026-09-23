import 'comment_model.dart';

enum ExpenseStatus {
  pending,
  approved,
  rejected;

  String get displayName {
    switch (this) {
      case ExpenseStatus.pending:
        return 'Pending';
      case ExpenseStatus.approved:
        return 'Approved';
      case ExpenseStatus.rejected:
        return 'Rejected';
    }
  }
}

enum JustificationStatus {
  none,
  required,
  submitted,
  approved,
  rejected,
  clarificationRequested;

  String get displayName {
    switch (this) {
      case JustificationStatus.none:
        return 'Not Required';
      case JustificationStatus.required:
        return 'Justification Required';
      case JustificationStatus.submitted:
        return 'Pending Review';
      case JustificationStatus.approved:
        return 'Justification Approved';
      case JustificationStatus.rejected:
        return 'Justification Rejected';
      case JustificationStatus.clarificationRequested:
        return 'Clarification Requested';
    }
  }
}

// Category A: Equipment
class EquipmentDetails {
  final String equipmentType;
  final bool isRental; // true = Rental, false = Purchase
  final int quantity;
  final double rentalAmount;
  final String rentalPeriod; // e.g., '3 days', '1 month'

  const EquipmentDetails({
    required this.equipmentType,
    required this.isRental,
    required this.quantity,
    this.rentalAmount = 0.0,
    this.rentalPeriod = '',
  });
}

// Category B: Transportation
enum TransportationType {
  local,
  privateCar,
  cng,
  uberPathao,
  bus,
  train,
  launch,
  other;

  String get displayName {
    switch (this) {
      case TransportationType.local:
        return 'Local';
      case TransportationType.privateCar:
        return 'Private Car';
      case TransportationType.cng:
        return 'CNG';
      case TransportationType.uberPathao:
        return 'Uber / Pathao';
      case TransportationType.bus:
        return 'Bus';
      case TransportationType.train:
        return 'Train';
      case TransportationType.launch:
        return 'Launch / Waterway';
      case TransportationType.other:
        return 'Other';
    }
  }

  static TransportationType fromString(String val) {
    switch (val.toLowerCase().replaceAll(' ', '').replaceAll('/', '').replaceAll('_', '')) {
      case 'privatecar':
      case 'car':
        return TransportationType.privateCar;
      case 'cng':
        return TransportationType.cng;
      case 'uberpathao':
      case 'uber':
      case 'pathao':
        return TransportationType.uberPathao;
      case 'bus':
        return TransportationType.bus;
      case 'train':
        return TransportationType.train;
      case 'launch':
      case 'boat':
        return TransportationType.launch;
      case 'other':
        return TransportationType.other;
      case 'local':
      default:
        return TransportationType.local;
    }
  }
}

class TransportationDetails {
  final TransportationType transportationType;
  final String fromLocation;
  final String toLocation;
  final String? vehicle;
  final double? distanceKm;
  final double? fuelCost;
  final double? otherTransportCost;

  const TransportationDetails({
    required this.transportationType,
    required this.fromLocation,
    required this.toLocation,
    this.vehicle,
    this.distanceKm,
    this.fuelCost,
    this.otherTransportCost,
  });

  double get costPerKm =>
      (distanceKm != null && distanceKm! > 0) ? ((fuelCost ?? 0) + (otherTransportCost ?? 0)) / distanceKm! : 0.0;
}

// Category C: Food
class FoodDetails {
  final String location;
  final String attendees;
  final int numberOfPeople;
  final String mealType; // Breakfast, Lunch, Dinner, Field Refreshments
  final bool exceedsFoodAllowance;

  const FoodDetails({
    required this.location,
    required this.attendees,
    required this.numberOfPeople,
    required this.mealType,
    this.exceedsFoodAllowance = false,
  });
}

// Category D: Accommodation
class AccommodationDetails {
  final String hotelName;
  final String location;
  final String guests;
  final int numberOfNights;
  final double ratePerNight;

  const AccommodationDetails({
    required this.hotelName,
    required this.location,
    required this.guests,
    required this.numberOfNights,
    required this.ratePerNight,
  });

  double get costPerPersonNight =>
      numberOfNights > 0 ? (ratePerNight * numberOfNights) / numberOfNights : ratePerNight;
}

// Category E: Office Cost
class OfficeCostDetails {
  final String subCategory; // Printing, Photocopy, Stationery, Internet, Communication, Meeting expenses, Temporary office, Other

  const OfficeCostDetails({
    required this.subCategory,
  });
}

class ExpenseModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String projectId;
  final String projectName;
  final String? taskId;
  final String? taskTitle;
  final double amount; // Direct Expense Amount
  final double officeBenefitAmount; // Auto-calculated 30%
  final String currency;
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final String note;
  final DateTime date;
  final bool hasReceipt; // 🟢 Receipt Available vs 🔴 No Receipt
  final String? receiptPhotoUrl;
  final ExpenseStatus status;
  final String? rejectionReason;
  final List<CommentModel> comments;
  final DateTime createdAt;

  // Justification fields (PRD Sections 11, 12, 13)
  final JustificationStatus justificationStatus;
  final String? justificationReason;
  final String? justificationComment;
  final String? justificationAttachmentUrl;
  final String? justificationReviewedBy;
  final String? justificationReviewComment;
  final DateTime? justificationReviewedAt;

  // Category-specific structured data
  final EquipmentDetails? equipmentDetails;
  final TransportationDetails? transportationDetails;
  final FoodDetails? foodDetails;
  final AccommodationDetails? accommodationDetails;
  final OfficeCostDetails? officeCostDetails;

  const ExpenseModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.projectId,
    required this.projectName,
    this.taskId,
    this.taskTitle,
    required this.amount,
    this.officeBenefitAmount = 0.0,
    this.currency = 'BDT',
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.note,
    required this.date,
    this.hasReceipt = true,
    this.receiptPhotoUrl,
    this.status = ExpenseStatus.pending,
    this.rejectionReason,
    this.comments = const [],
    required this.createdAt,
    this.justificationStatus = JustificationStatus.none,
    this.justificationReason,
    this.justificationComment,
    this.justificationAttachmentUrl,
    this.justificationReviewedBy,
    this.justificationReviewComment,
    this.justificationReviewedAt,
    this.equipmentDetails,
    this.transportationDetails,
    this.foodDetails,
    this.accommodationDetails,
    this.officeCostDetails,
  });

  double get totalWithBenefit => amount + officeBenefitAmount;

  ExpenseModel copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? projectId,
    String? projectName,
    String? taskId,
    String? taskTitle,
    double? amount,
    double? officeBenefitAmount,
    String? currency,
    String? categoryId,
    String? categoryName,
    String? categoryIcon,
    String? note,
    DateTime? date,
    bool? hasReceipt,
    String? receiptPhotoUrl,
    ExpenseStatus? status,
    String? rejectionReason,
    List<CommentModel>? comments,
    DateTime? createdAt,
    JustificationStatus? justificationStatus,
    String? justificationReason,
    String? justificationComment,
    String? justificationAttachmentUrl,
    String? justificationReviewedBy,
    String? justificationReviewComment,
    DateTime? justificationReviewedAt,
    EquipmentDetails? equipmentDetails,
    TransportationDetails? transportationDetails,
    FoodDetails? foodDetails,
    AccommodationDetails? accommodationDetails,
    OfficeCostDetails? officeCostDetails,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      amount: amount ?? this.amount,
      officeBenefitAmount: officeBenefitAmount ?? this.officeBenefitAmount,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      note: note ?? this.note,
      date: date ?? this.date,
      hasReceipt: hasReceipt ?? this.hasReceipt,
      receiptPhotoUrl: receiptPhotoUrl ?? this.receiptPhotoUrl,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      justificationStatus: justificationStatus ?? this.justificationStatus,
      justificationReason: justificationReason ?? this.justificationReason,
      justificationComment: justificationComment ?? this.justificationComment,
      justificationAttachmentUrl: justificationAttachmentUrl ?? this.justificationAttachmentUrl,
      justificationReviewedBy: justificationReviewedBy ?? this.justificationReviewedBy,
      justificationReviewComment: justificationReviewComment ?? this.justificationReviewComment,
      justificationReviewedAt: justificationReviewedAt ?? this.justificationReviewedAt,
      equipmentDetails: equipmentDetails ?? this.equipmentDetails,
      transportationDetails: transportationDetails ?? this.transportationDetails,
      foodDetails: foodDetails ?? this.foodDetails,
      accommodationDetails: accommodationDetails ?? this.accommodationDetails,
      officeCostDetails: officeCostDetails ?? this.officeCostDetails,
    );
  }
}
