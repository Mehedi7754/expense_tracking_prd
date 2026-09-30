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

  static ExpenseStatus fromString(String val) {
    switch (val.toLowerCase().replaceAll(' ', '').replaceAll('_', '')) {
      case 'approved':
        return ExpenseStatus.approved;
      case 'rejected':
        return ExpenseStatus.rejected;
      case 'pending':
      default:
        return ExpenseStatus.pending;
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

  static JustificationStatus fromString(String val) {
    switch (val.toLowerCase().replaceAll(' ', '').replaceAll('_', '')) {
      case 'required':
        return JustificationStatus.required;
      case 'submitted':
        return JustificationStatus.submitted;
      case 'approved':
        return JustificationStatus.approved;
      case 'rejected':
        return JustificationStatus.rejected;
      case 'clarificationrequested':
        return JustificationStatus.clarificationRequested;
      case 'none':
      default:
        return JustificationStatus.none;
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

  factory EquipmentDetails.fromJson(Map<String, dynamic> json) {
    return EquipmentDetails(
      equipmentType: (json['equipment_type'] ?? json['equipmentType'] ?? '').toString(),
      isRental: json['is_rental'] ?? json['isRental'] ?? true,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      rentalAmount: (json['rental_amount'] ?? json['rentalAmount'] as num?)?.toDouble() ?? 0.0,
      rentalPeriod: (json['rental_period'] ?? json['rentalPeriod'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'equipment_type': equipmentType,
      'is_rental': isRental,
      'quantity': quantity,
      'rental_amount': rentalAmount,
      'rental_period': rentalPeriod,
    };
  }
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

  factory TransportationDetails.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['transportation_type'] ?? json['transportationType'] ?? 'local').toString();
    return TransportationDetails(
      transportationType: TransportationType.fromString(typeStr),
      fromLocation: (json['from_location'] ?? json['fromLocation'] ?? '').toString(),
      toLocation: (json['to_location'] ?? json['toLocation'] ?? '').toString(),
      vehicle: json['vehicle']?.toString(),
      distanceKm: (json['distance_km'] ?? json['distanceKm'] as num?)?.toDouble(),
      fuelCost: (json['fuel_cost'] ?? json['fuelCost'] as num?)?.toDouble(),
      otherTransportCost: (json['other_transport_cost'] ?? json['otherTransportCost'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transportation_type': transportationType.name,
      'from_location': fromLocation,
      'to_location': toLocation,
      if (vehicle != null) 'vehicle': vehicle,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (fuelCost != null) 'fuel_cost': fuelCost,
      if (otherTransportCost != null) 'other_transport_cost': otherTransportCost,
    };
  }
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

  factory FoodDetails.fromJson(Map<String, dynamic> json) {
    return FoodDetails(
      location: (json['location'] ?? '').toString(),
      attendees: (json['attendees'] ?? '').toString(),
      numberOfPeople: (json['number_of_people'] ?? json['numberOfPeople'] as num?)?.toInt() ?? 1,
      mealType: (json['meal_type'] ?? json['mealType'] ?? 'Lunch').toString(),
      exceedsFoodAllowance: json['exceeds_food_allowance'] ?? json['exceedsFoodAllowance'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location': location,
      'attendees': attendees,
      'number_of_people': numberOfPeople,
      'meal_type': mealType,
      'exceeds_food_allowance': exceedsFoodAllowance,
    };
  }
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

  factory AccommodationDetails.fromJson(Map<String, dynamic> json) {
    return AccommodationDetails(
      hotelName: (json['hotel_name'] ?? json['hotelName'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      guests: (json['guests'] ?? '').toString(),
      numberOfNights: (json['number_of_nights'] ?? json['numberOfNights'] as num?)?.toInt() ?? 1,
      ratePerNight: (json['rate_per_night'] ?? json['ratePerNight'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hotel_name': hotelName,
      'location': location,
      'guests': guests,
      'number_of_nights': numberOfNights,
      'rate_per_night': ratePerNight,
    };
  }
}

// Category E: Office Cost
class OfficeCostDetails {
  final String subCategory; // Printing, Photocopy, Stationery, Internet, Communication, Meeting expenses, Temporary office, Other

  const OfficeCostDetails({
    required this.subCategory,
  });

  factory OfficeCostDetails.fromJson(Map<String, dynamic> json) {
    return OfficeCostDetails(
      subCategory: (json['sub_category'] ?? json['subCategory'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sub_category': subCategory,
    };
  }
}

class ExpenseModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String projectId;
  final String projectName;
  final String? taskId;
  final String? taskTitle;
  final double amount; // Total Direct Expense Cost (Base Cost + Tax)
  final double baseCost; // Base Cost before Tax
  final double taxRate; // Tax percentage (e.g. 5.0, 7.5, 10.0, 15.0)
  final double taxAmount; // Calculated Tax: baseCost * (taxRate / 100)
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
    double? baseCost,
    this.taxRate = 0.0,
    double? taxAmount,
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
  })  : baseCost = baseCost ?? amount,
        taxAmount = taxAmount ?? 0.0;

  /// Explicit getter for total cost (Gross invoice total: Base Cost + Tax Amount).
  double get totalCost => hasTax ? (baseCost + taxAmount) : amount;

  /// Whether tax is applied to this expense.
  bool get hasTax => taxRate > 0 && taxAmount > 0;

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
    double? baseCost,
    double? taxRate,
    double? taxAmount,
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
      baseCost: baseCost ?? this.baseCost,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
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

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    List<CommentModel> parseComments(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map(CommentModel.fromJson)
            .toList();
      }
      return const [];
    }

    final statusStr = (json['status'] ?? 'pending').toString();
    final justStatusStr = (json['justification_status'] ?? json['justificationStatus'] ?? 'none').toString();

    // Check category details object (from JSONB in PostgreSQL or nested camelCase)
    final categoryDetails = json['category_details'] is Map<String, dynamic>
        ? json['category_details'] as Map<String, dynamic>
        : null;

    final eqData = json['equipment_details'] ?? json['equipmentDetails'] ?? categoryDetails?['equipment'];
    final trData = json['transportation_details'] ?? json['transportationDetails'] ?? categoryDetails?['transportation'];
    final fdData = json['food_details'] ?? json['foodDetails'] ?? categoryDetails?['food'];
    final acData = json['accommodation_details'] ?? json['accommodationDetails'] ?? categoryDetails?['accommodation'];
    final ofData = json['office_cost_details'] ?? json['officeCostDetails'] ?? categoryDetails?['office'];

    return ExpenseModel(
      id: (json['id'] ?? '').toString(),
      employeeId: (json['employee_id'] ?? json['employeeId'] ?? '').toString(),
      employeeName: (json['employee_name'] ?? json['employeeName'] ?? '').toString(),
      projectId: (json['project_id'] ?? json['projectId'] ?? '').toString(),
      projectName: (json['project_name'] ?? json['projectName'] ?? '').toString(),
      taskId: json['task_id']?.toString() ?? json['taskId']?.toString(),
      taskTitle: json['task_title']?.toString() ?? json['taskTitle']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      officeBenefitAmount: (json['office_benefit_amount'] ?? json['officeBenefitAmount'] as num?)?.toDouble() ?? 0.0,
      currency: (json['currency'] ?? 'BDT').toString(),
      categoryId: (json['category_id'] ?? json['categoryId'] ?? '').toString(),
      categoryName: (json['category_name'] ?? json['categoryName'] ?? '').toString(),
      categoryIcon: (json['category_icon'] ?? json['categoryIcon'] ?? 'receipt').toString(),
      note: (json['note'] ?? '').toString(),
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      hasReceipt: json['has_receipt'] ?? json['hasReceipt'] ?? true,
      receiptPhotoUrl: json['receipt_photo_url']?.toString() ?? json['receiptPhotoUrl']?.toString(),
      status: ExpenseStatus.fromString(statusStr),
      rejectionReason: json['rejection_reason']?.toString() ?? json['rejectionReason']?.toString(),
      comments: parseComments(json['comments']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      justificationStatus: JustificationStatus.fromString(justStatusStr),
      justificationReason: json['justification_reason']?.toString() ?? json['justificationReason']?.toString(),
      justificationComment: json['justification_comment']?.toString() ?? json['justificationComment']?.toString(),
      justificationAttachmentUrl: json['justification_attachment_url']?.toString() ?? json['justificationAttachmentUrl']?.toString(),
      justificationReviewedBy: json['justification_reviewed_by']?.toString() ?? json['justificationReviewedBy']?.toString(),
      justificationReviewComment: json['justification_review_comment']?.toString() ?? json['justificationReviewComment']?.toString(),
      justificationReviewedAt: json['justification_reviewed_at'] != null
          ? DateTime.tryParse(json['justification_reviewed_at'].toString())
          : null,
      equipmentDetails: eqData is Map<String, dynamic> ? EquipmentDetails.fromJson(eqData) : null,
      transportationDetails: trData is Map<String, dynamic> ? TransportationDetails.fromJson(trData) : null,
      foodDetails: fdData is Map<String, dynamic> ? FoodDetails.fromJson(fdData) : null,
      accommodationDetails: acData is Map<String, dynamic> ? AccommodationDetails.fromJson(acData) : null,
      officeCostDetails: ofData is Map<String, dynamic> ? OfficeCostDetails.fromJson(ofData) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'project_id': projectId,
      'project_name': projectName,
      if (taskId != null) 'task_id': taskId,
      if (taskTitle != null) 'task_title': taskTitle,
      'amount': amount,
      'office_benefit_amount': officeBenefitAmount,
      'currency': currency,
      'category_id': categoryId,
      'category_name': categoryName,
      'category_icon': categoryIcon,
      'note': note,
      'date': date.toIso8601String(),
      'has_receipt': hasReceipt,
      if (receiptPhotoUrl != null) 'receipt_photo_url': receiptPhotoUrl,
      'status': status.name,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      'comments': comments.map((c) => c.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'justification_status': justificationStatus.name,
      if (justificationReason != null) 'justification_reason': justificationReason,
      if (justificationComment != null) 'justification_comment': justificationComment,
      if (justificationAttachmentUrl != null) 'justification_attachment_url': justificationAttachmentUrl,
      if (justificationReviewedBy != null) 'justification_reviewed_by': justificationReviewedBy,
      if (justificationReviewComment != null) 'justification_review_comment': justificationReviewComment,
      if (justificationReviewedAt != null) 'justification_reviewed_at': justificationReviewedAt!.toIso8601String(),
      if (equipmentDetails != null) 'equipment_details': equipmentDetails!.toJson(),
      if (transportationDetails != null) 'transportation_details': transportationDetails!.toJson(),
      if (foodDetails != null) 'food_details': foodDetails!.toJson(),
      if (accommodationDetails != null) 'accommodation_details': accommodationDetails!.toJson(),
      if (officeCostDetails != null) 'office_cost_details': officeCostDetails!.toJson(),
    };
  }
}
