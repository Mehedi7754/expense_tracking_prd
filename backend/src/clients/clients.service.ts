import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class ClientsService {
  constructor(private readonly db: DatabaseService) {}

  async findAll() {
    const res = await this.db.query('SELECT * FROM clients ORDER BY name ASC');
    return res.rows.map((r) => ({
      id: r.id,
      name: r.name,
      clientType: r.client_type,
      contactPerson: r.contact_person,
      email: r.email,
      phone: r.phone,
      address: r.address,
      notes: r.notes,
    }));
  }

  async create(data: any) {
    const res = await this.db.query(
      `INSERT INTO clients (name, client_type, contact_person, email, phone, address, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        data.name,
        data.clientType || data.client_type || 'private',
        data.contactPerson || data.contact_person || 'Contact Person',
        data.email,
        data.phone,
        data.address,
        data.notes,
      ],
    );
    const r = res.rows[0];
    return {
      id: r.id,
      name: r.name,
      clientType: r.client_type,
      contactPerson: r.contact_person,
      email: r.email,
      phone: r.phone,
      address: r.address,
      notes: r.notes,
    };
  }
}
