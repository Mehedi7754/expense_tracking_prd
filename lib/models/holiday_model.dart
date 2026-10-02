class HolidayModel {
  final String id;
  final String date;
  final String name;
  final bool isRecurring;

  const HolidayModel({
    required this.id,
    required this.date,
    required this.name,
    this.isRecurring = false,
  });

  factory HolidayModel.fromJson(Map<String, dynamic> json) {
    return HolidayModel(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isRecurring: json['isRecurring'] as bool? ?? json['is_recurring'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'name': name,
      'isRecurring': isRecurring,
    };
  }
}
