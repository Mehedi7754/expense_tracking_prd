import { BadRequestException, NotFoundException } from '@nestjs/common';
import { CategoriesService } from './categories.service';

describe('CategoriesService', () => {
  let db: { query: jest.Mock };
  let service: CategoriesService;

  beforeEach(() => {
    db = { query: jest.fn() };
    service = new CategoriesService(db as any);
  });

  it('lists active and inactive categories with Transportation first', async () => {
    db.query.mockResolvedValue({ rows: [] });

    await service.findAll();

    expect(db.query.mock.calls[0][0]).toContain('ORDER BY CASE');
    expect(db.query.mock.calls[0][0]).not.toContain('WHERE is_active = TRUE');
  });

  it('persists category edits and returns the saved row', async () => {
    db.query.mockResolvedValue({
      rows: [{ id: 'cat-1', name: 'Transportation', icon_name: 'transport', is_default: false, is_active: true }],
    });

    const result = await service.update('cat-1', { name: 'Transportation', iconName: 'transport' });

    expect(db.query).toHaveBeenCalledWith(expect.stringContaining('UPDATE categories'), [
      'cat-1', 'Transportation', 'transport', undefined,
    ]);
    expect(result.name).toBe('Transportation');
  });

  it('rejects category names that are blank', async () => {
    await expect(service.update('cat-1', { name: '   ' })).rejects.toBeInstanceOf(BadRequestException);
    expect(db.query).not.toHaveBeenCalled();
  });

  it('deactivates a category instead of deleting expense history references', async () => {
    db.query.mockResolvedValue({
      rows: [{ id: 'cat-1', name: 'Food', icon_name: 'meal', is_default: false, is_active: false }],
    });

    const result = await service.remove('cat-1');

    expect(db.query.mock.calls[0][0]).toContain('SET is_active = FALSE');
    expect(db.query.mock.calls[0][0]).not.toContain('DELETE FROM');
    expect(result.isActive).toBe(false);
  });

  it('returns not found when editing a missing category', async () => {
    db.query.mockResolvedValue({ rows: [] });

    await expect(service.update('missing', { name: 'Food' })).rejects.toBeInstanceOf(NotFoundException);
  });
});
