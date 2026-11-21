import { BadRequestException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

export async function resolveCanonicalDepartment(db: DatabaseService, input: unknown): Promise<string> {
  const name = (typeof input === 'string' ? input : '').trim().replace(/\s+/g, ' ') || 'General';
  if (name.length > 100) throw new BadRequestException('Department name must be 100 characters or fewer');

  await db.query('INSERT INTO departments (name) VALUES ($1) ON CONFLICT DO NOTHING', [name]);
  const result = await db.query(
    'SELECT name FROM departments WHERE LOWER(TRIM(name)) = LOWER($1) LIMIT 1',
    [name],
  );
  if (!result.rows.length) throw new BadRequestException('Unable to resolve department');
  return result.rows[0].name;
}
