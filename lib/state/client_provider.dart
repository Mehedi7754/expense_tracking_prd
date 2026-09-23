import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_model.dart';

class ClientNotifier extends Notifier<List<ClientModel>> {
  static const List<ClientModel> _initialClients = [
    ClientModel(
      id: 'client_01',
      name: 'Apex Technologies Inc.',
      clientType: ClientType.private,
      contactPerson: 'Marcus Vance, VP of Engineering',
      email: 'm.vance@apextech.com',
      phone: '+880 2-55007077',
      address: 'Silicon Tower, Level 14, Gulshan-2, Dhaka',
      notes: 'Enterprise Cloud ERP migration, multi-tenant billing & HR systems.',
    ),
    ClientModel(
      id: 'client_02',
      name: 'Prime Bank Digital',
      clientType: ClientType.private,
      contactPerson: 'Farhana Kabir, Head of Digital Banking',
      email: 'digital@primebank.com',
      phone: '+880 2-55138053',
      address: 'Prime Tower, 68 Motijheel C/A, Dhaka',
      notes: 'Omnichannel iOS & Android mobile banking, payment gateway integration.',
    ),
    ClientModel(
      id: 'client_03',
      name: 'BioHealth AI Corp',
      clientType: ClientType.private,
      contactPerson: 'Dr. Aris Thorne, Chief Medical Officer',
      email: 'contact@biohealthai.io',
      phone: '+880 2-222281265',
      address: 'BioTech Innovation Hub, Banani, Dhaka',
      notes: 'HIPAA-compliant telehealth platform & AI medical NLP diagnostics.',
    ),
    ClientModel(
      id: 'client_04',
      name: 'GovTech Defense Systems',
      clientType: ClientType.government,
      contactPerson: 'Col. Tariq Rahman, Director of Cybersecurity',
      email: 'tariq.rahman@govtech.gov.bd',
      phone: '+880 2-55667000',
      address: 'National Cyber Security Complex, Agargaon, Dhaka',
      notes: 'Automated CI/CD security scanning, Kubernetes posture & 24/7 SOC.',
    ),
    ClientModel(
      id: 'client_05',
      name: 'Apex Logistics Cloud',
      clientType: ClientType.private,
      contactPerson: 'Syed Nasim Manzur, Managing Director',
      email: 'info@apexlogistics.io',
      phone: '+880 2-9883358',
      address: 'Apex Cloud Hub, 99 Gulshan Avenue, Dhaka',
      notes: 'High-throughput Kafka streaming & multi-vendor warehouse logistics SaaS.',
    ),
  ];

  @override
  List<ClientModel> build() => _initialClients;

  void addClient(ClientModel client) {
    state = [...state, client];
  }

  void updateClient(ClientModel updated) {
    state = [
      for (final c in state)
        if (c.id == updated.id) updated else c,
    ];
  }
}

final clientProvider = NotifierProvider<ClientNotifier, List<ClientModel>>(ClientNotifier.new);
