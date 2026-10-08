import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { ExpensesService } from './expenses.service';

describe('ExpensesService Unit & Business Rules', () => {
  let service: ExpensesService;
  let mockDb: any;
  let mockAudit: any;
  let mockNotifications: any;

  beforeEach(() => {
    mockDb = {
      query: jest.fn(),
      transaction: jest.fn(),
    };
    mockAudit = {
      log: jest.fn().mockResolvedValue(true),
    };
    mockNotifications = {
      create: jest.fn().mockResolvedValue(true),
    };
    const mockEmailService = {
      sendCheckInConfirmation: jest.fn().mockResolvedValue({}),
      sendNewExpenseNotification: jest.fn().mockResolvedValue({}),
    };

    service = new ExpensesService(mockDb, mockAudit, mockNotifications, mockEmailService as any);
  });

  describe('Anti-Fraud and Approval Rules', () => {
    it('throws ForbiddenException when a reviewer tries to approve their own expense report', async () => {
      const expenseId = 'exp-123';
      const reviewerId = 'user-owner';

      jest.spyOn(service, 'findOne').mockResolvedValue({
        id: expenseId,
        employeeId: reviewerId,
        amount: 5000,
        currency: 'BDT',
        categoryName: 'Food',
        projectId: 'p-1',
      } as any);

      await expect(service.approve(expenseId, reviewerId, 'Self approval')).rejects.toThrow(
        ForbiddenException,
      );
      await expect(service.approve(expenseId, reviewerId, 'Self approval')).rejects.toThrow(
        /Anti-fraud rule: You cannot approve your own expense report/,
      );
    });

    it('approves successfully when reviewer is different from expense submitter', async () => {
      const expenseId = 'exp-123';
      const submitterId = 'user-emp-01';
      const reviewerId = 'user-mgr-01';

      jest.spyOn(service, 'findOne').mockResolvedValue({
        id: expenseId,
        employeeId: submitterId,
        amount: 2500,
        currency: 'BDT',
        categoryName: 'Transport',
        projectId: 'p-1',
      } as any);

      mockDb.query
        .mockResolvedValueOnce({ rows: [] }) // update expenses
        .mockResolvedValueOnce({ rows: [{ full_name: 'Manager Sarah', role: 'project_manager' }] }); // reviewer query

      const result = await service.approve(expenseId, reviewerId, 'Approved for survey team');
      expect(mockDb.query).toHaveBeenCalledWith(
        expect.stringContaining("UPDATE expenses\n       SET status = 'approved'"),
        expect.arrayContaining([reviewerId, 'Approved for survey team', expenseId]),
      );
      expect(mockNotifications.create).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: submitterId,
          type: 'expense_approved',
        }),
      );
    });
  });

  describe('IDOR & Access Control', () => {
    it('throws ForbiddenException when a member attempts to view an expense not belonging to their project', async () => {
      mockDb.query.mockResolvedValue({
        rows: [
          {
            id: 'exp-other',
            employee_id: 'other-user',
            project_id: 'proj-other',
            amount: '3000',
            currency: 'BDT',
            status: 'pending',
            category_name: 'Equipment',
            category_icon: 'laptop',
            comments: [],
            has_receipt: true,
            receipt_photo_url: null,
            justification_status: null,
            justification_reason: null,
            category_details: '{}',
            created_at: new Date().toISOString(),
            date: '2026-10-01',
          },
        ],
      });

      const regularUser = {
        id: 'user-regular',
        role: 'project_member',
        assignedProjectIds: ['proj-mine'],
      };

      await expect(service.findOne('exp-other', regularUser)).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('allows a member to view their own expense report', async () => {
      const userId = 'user-regular';
      mockDb.query.mockResolvedValue({
        rows: [
          {
            id: 'exp-mine',
            employee_id: userId,
            project_id: 'proj-mine',
            amount: '1200',
            currency: 'BDT',
            status: 'pending',
            category_name: 'Food',
            category_icon: 'dining',
            comments: [],
            has_receipt: true,
            receipt_photo_url: null,
            justification_status: null,
            justification_reason: null,
            category_details: '{}',
            created_at: new Date().toISOString(),
            date: '2026-10-01',
          },
        ],
      });

      const regularUser = {
        id: userId,
        role: 'project_member',
        assignedProjectIds: ['proj-mine'],
      };

      const exp = await service.findOne('exp-mine', regularUser);
      expect(exp.id).toBe('exp-mine');
      expect(exp.employeeId).toBe(userId);
    });
  });

  describe('Update Validation', () => {
    it('throws ForbiddenException when a member tries to edit an approved expense', async () => {
      jest.spyOn(service, 'findOne').mockResolvedValue({
        id: 'exp-1',
        employeeId: 'u-1',
        status: 'approved',
      } as any);

      const user = { id: 'u-1', role: 'project_member' };
      await expect(service.update('exp-1', { amount: 9999 }, user)).rejects.toThrow(
        /Cannot edit an expense that has already been approved/,
      );
    });
  });
});
