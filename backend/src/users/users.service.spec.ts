import { BadRequestException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { UsersService } from './users.service';

describe('UsersService department merging', () => {
  it('moves staff to the selected canonical department before removing the duplicate', async () => {
    const client = { query: jest.fn()
      .mockResolvedValueOnce({ rows: [{ id: 'source-id', name: 'Survy' }, { id: 'target-id', name: 'Survey' }] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] }) };
    const db = {
      transaction: jest.fn(async (callback: (transactionClient: any) => Promise<unknown>) => callback(client)),
    };
    const service = new UsersService(db as unknown as DatabaseService, {} as any, {} as any);

    await expect(service.mergeDepartments('source-id', 'target-id')).resolves.toEqual({ id: 'target-id', name: 'Survey' });
    expect(client.query.mock.calls[1]).toEqual([
      'UPDATE users SET department = $1, updated_at = NOW() WHERE LOWER(TRIM(department)) = LOWER($2)',
      ['Survey', 'Survy'],
    ]);
    expect(client.query.mock.calls[2]).toEqual(['DELETE FROM departments WHERE id = $1', ['source-id']]);
  });

  it('rejects merging a department into itself', async () => {
    const db = { transaction: jest.fn() };
    const service = new UsersService(db as unknown as DatabaseService, {} as any, {} as any);
    await expect(service.mergeDepartments('same', 'same')).rejects.toBeInstanceOf(BadRequestException);
    expect(db.transaction).not.toHaveBeenCalled();
  });
});
