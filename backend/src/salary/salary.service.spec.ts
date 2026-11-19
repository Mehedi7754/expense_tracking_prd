import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { SalaryService } from './salary.service';

describe('SalaryService leave access and decisions', () => {
  let service: SalaryService;
  let db: { query: jest.Mock };

  beforeEach(() => {
    db = { query: jest.fn().mockResolvedValue({ rows: [] }) };
    service = new SalaryService(db as unknown as DatabaseService);
  });

  it('limits project managers to leave requests from assigned project members', async () => {
    await service.getLeaves(undefined, undefined, undefined, {
      id: 'manager-1', role: 'project_manager', assignedProjectIds: ['project-1'],
    });

    expect(db.query.mock.calls[0][0]).toContain('project_members');
    expect(db.query.mock.calls[0][1]).toEqual([['project-1']]);
  });

  it('blocks project managers from approving leave outside their assigned projects', async () => {
    await expect(service.setLeaveDecision('leave-1', true, {
      id: 'manager-1', role: 'project_manager', assignedProjectIds: ['project-1'],
    })).rejects.toBeInstanceOf(ForbiddenException);
    expect(db.query).toHaveBeenCalledTimes(1);
  });

  it('only updates a pending leave request', async () => {
    db.query
      .mockResolvedValueOnce({ rows: [{ id: 'leave-1', user_id: 'member-1', start_date: '2026-11-02', end_date: '2026-11-03', leave_type: 'casual', reason: '', is_approved: true, status: 'approved' }] })
      .mockResolvedValueOnce({ rows: [{ full_name: 'Member', email: 'member@example.com' }] });

    await service.setLeaveDecision('leave-1', true, { id: 'admin-1', role: 'main_admin' });
    expect(db.query.mock.calls[0][0]).toContain("status = 'pending'");
  });

  it('rejects empty clarification messages before writing', async () => {
    await expect(service.addLeaveComment('leave-1', 'member-1', '  ', {
      id: 'member-1', role: 'project_member',
    })).rejects.toBeInstanceOf(BadRequestException);
    expect(db.query).not.toHaveBeenCalled();
  });

  it('sends a reviewer clarification to the leave owner with a deep link', async () => {
    const notifications = { create: jest.fn().mockResolvedValue({}) };
    service = new SalaryService(db as unknown as DatabaseService, notifications as any);
    db.query
      .mockResolvedValueOnce({ rows: [{ user_id: 'member-1' }] })
      .mockResolvedValueOnce({ rows: [{ user_id: 'member-1', start_date: '2026-11-20', end_date: '2026-11-21', leave_type: 'casual' }] })
      .mockResolvedValueOnce({ rows: [{ full_name: 'Manager', role: 'project_manager', avatar_url: null }] })
      .mockResolvedValueOnce({ rows: [{ id: 'comment-1', leave_id: 'leave-1', author_id: 'manager-1', author_name: 'Manager', author_role: 'project_manager', comment_text: 'Please clarify', created_at: new Date() }] });

    await service.addLeaveComment('leave-1', 'manager-1', 'Please clarify', {
      id: 'manager-1', role: 'main_admin',
    });

    expect(notifications.create).toHaveBeenCalledWith(expect.objectContaining({
      userId: 'member-1', type: 'leave_comment', relatedLeaveId: 'leave-1',
    }));
  });

  it('casts the user role enum before reading clarification authors', async () => {
    db.query
      .mockResolvedValueOnce({ rows: [{ user_id: 'member-1' }] })
      .mockResolvedValueOnce({ rows: [] });
    await service.getLeaveComments('leave-1', { id: 'member-1', role: 'project_member' });
    expect(db.query.mock.calls[1][0]).toContain('COALESCE(u.role::text, c.author_role)');
  });
});
