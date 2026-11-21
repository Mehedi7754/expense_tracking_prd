import { BadRequestException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { resolveCanonicalDepartment } from './department.util';

describe('resolveCanonicalDepartment', () => {
  it('returns the existing canonical spelling for case-insensitive matches', async () => {
    const db = { query: jest.fn()
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ name: 'GIS & Survey' }] }) };

    await expect(resolveCanonicalDepartment(db as unknown as DatabaseService, '  gis & survey  '))
      .resolves.toBe('GIS & Survey');
    expect(db.query).toHaveBeenNthCalledWith(1,
      'INSERT INTO departments (name) VALUES ($1) ON CONFLICT DO NOTHING', ['gis & survey']);
    expect(db.query.mock.calls[1][1]).toEqual(['gis & survey']);
  });

  it('uses General when the department is empty', async () => {
    const db = { query: jest.fn()
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ name: 'General' }] }) };

    await expect(resolveCanonicalDepartment(db as unknown as DatabaseService, '')).resolves.toBe('General');
  });

  it('rejects overlong department names', async () => {
    const db = { query: jest.fn() };
    await expect(resolveCanonicalDepartment(db as unknown as DatabaseService, 'D'.repeat(101)))
      .rejects.toBeInstanceOf(BadRequestException);
    expect(db.query).not.toHaveBeenCalled();
  });
});
