import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class CategoriesService {
  constructor(private readonly db: DatabaseService) {}

  async findAll() {
    const res = await this.db.query(
      'SELECT id, name, icon_name, is_default, is_active FROM categories WHERE is_active = TRUE ORDER BY name ASC',
    );
    return res.rows.map((r) => ({
      id: r.id,
      name: r.name,
      iconName: r.icon_name,
      isDefault: r.is_default,
      isActive: r.is_active,
    }));
  }

  async create(data: { name: string; iconName?: string; isDefault?: boolean }) {
    const res = await this.db.query(
      `INSERT INTO categories (name, icon_name, is_default)
       VALUES ($1, $2, $3)
       RETURNING id, name, icon_name, is_default, is_active`,
      [data.name, data.iconName || 'category', Boolean(data.isDefault)],
    );
    const r = res.rows[0];
    return {
      id: r.id,
      name: r.name,
      iconName: r.icon_name,
      isDefault: r.is_default,
      isActive: r.is_active,
    };
  }
}
