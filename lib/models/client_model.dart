enum ClientType {
  government,
  private,
  ngo,
  international,
  other;

  String get displayName {
    switch (this) {
      case ClientType.government:
        return 'Government';
      case ClientType.private:
        return 'Private';
      case ClientType.ngo:
        return 'NGO';
      case ClientType.international:
        return 'International';
      case ClientType.other:
        return 'Other';
    }
  }

  static ClientType fromString(String val) {
    switch (val.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '')) {
      case 'government':
        return ClientType.government;
      case 'ngo':
        return ClientType.ngo;
      case 'international':
        return ClientType.international;
      case 'other':
        return ClientType.other;
      case 'private':
      default:
        return ClientType.private;
    }
  }
}

class ClientModel {
  final String id;
  final String name;
  final ClientType clientType;
  final String contactPerson;
  final String email;
  final String phone;
  final String address;
  final String? notes;

  const ClientModel({
    required this.id,
    required this.name,
    this.clientType = ClientType.private,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.address,
    this.notes,
  });

  ClientModel copyWith({
    String? id,
    String? name,
    ClientType? clientType,
    String? contactPerson,
    String? email,
    String? phone,
    String? address,
    String? notes,
  }) {
    return ClientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      clientType: clientType ?? this.clientType,
      contactPerson: contactPerson ?? this.contactPerson,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
    );
  }

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['client_type'] ?? json['clientType'] ?? 'private').toString();
    return ClientModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      clientType: ClientType.fromString(typeStr),
      contactPerson: (json['contact_person'] ?? json['contactPerson'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'client_type': clientType.name,
      'contact_person': contactPerson,
      'email': email,
      'phone': phone,
      'address': address,
      if (notes != null) 'notes': notes,
    };
  }
}
