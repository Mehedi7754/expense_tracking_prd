import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class CategoriesService {
  constructor(private readonly db: DatabaseService) {}

  async findAll() {
    const res = await this.db.query(
      `SELECT id, name, icon_name, is_default, is_active
       FROM categories
       ORDER BY CASE WHEN LOWER(TRIM(name)) = 'transportation' THEN 0 ELSE 1 END, LOWER(name) ASC`,
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
    const name = data.name?.trim();
    if (!name) throw new BadRequestException('Category name is required');
    const res = await this.db.query(
      `INSERT INTO categories (name, icon_name, is_default)
       VALUES ($1, $2, $3)
       RETURNING id, name, icon_name, is_default, is_active`,
      [name, data.iconName || 'category', Boolean(data.isDefault)],
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

  async update(
    id: string,
    data: { name?: string; iconName?: string; isActive?: boolean },
  ) {
    const name = data.name === undefined ? undefined : data.name.trim();
    if (name !== undefined && !name) {
      throw new BadRequestException('Category name cannot be empty');
    }
    if (data.isActive !== undefined && typeof data.isActive !== 'boolean') {
      throw new BadRequestException('isActive must be a boolean');
    }

    let res;
    try {
      res = await this.db.query(
        `UPDATE categories
         SET name = COALESCE($2, name),
             icon_name = COALESCE($3, icon_name),
             is_active = COALESCE($4, is_active),
             updated_at = NOW()
         WHERE id = $1
         RETURNING id, name, icon_name, is_default, is_active`,
        [id, name, data.iconName?.trim(), data.isActive],
      );
    } catch (error) {
      if ((error as { code?: string }).code === '23505') {
        throw new ConflictException('A category with this name already exists');
      }
      throw error;
    }

    if (!res.rows.length) throw new NotFoundException('Category not found');
    return this.toCategory(res.rows[0]);
  }

  async remove(id: string) {
    const res = await this.db.query(
      `UPDATE categories
       SET is_active = FALSE, updated_at = NOW()
       WHERE id = $1
       RETURNING id, name, icon_name, is_default, is_active`,
      [id],
    );
    if (!res.rows.length) throw new NotFoundException('Category not found');
    return this.toCategory(res.rows[0]);
  }

  private toCategory(row: any) {
    return {
      id: row.id,
      name: row.name,
      iconName: row.icon_name,
      isDefault: row.is_default,
      isActive: row.is_active,
    };
  }
}
