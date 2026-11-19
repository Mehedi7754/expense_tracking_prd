import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { ProjectsService } from './projects.service';

describe('ProjectsService Unit & Access Rules', () => {
  let service: ProjectsService;
  let mockDb: any;
  let mockAudit: any;

  beforeEach(() => {
    mockDb = {
      query: jest.fn().mockResolvedValue({ rows: [] }),
      transaction: jest.fn(),
    };
    mockAudit = {
      log: jest.fn().mockResolvedValue(true),
    };
    const mockNotifications = {
      createNotification: jest.fn().mockResolvedValue(true),
    };
    const mockFcm = {
      sendPushToProjectMembers: jest.fn().mockResolvedValue(true),
      sendPushToAdmins: jest.fn().mockResolvedValue(true),
      sendPushToUser: jest.fn().mockResolvedValue(true),
    };
    service = new ProjectsService(mockDb, mockAudit, mockNotifications as any, mockFcm as any);
  });

  it('maps saved site coordinates and rejects incomplete or out-of-range pins', () => {
    const mapped = (service as any).mapProjectRow({
      id: 'p1', project_code: 'PRJ-1', name: 'Survey',
      site_latitude: '23.8103000', site_longitude: '90.4125000',
    });
    expect(mapped.siteLatitude).toBe(23.8103);
    expect(mapped.siteLongitude).toBe(90.4125);
    expect((service as any).parseSiteLocation({ siteLatitude: 23.81, siteLongitude: 90.41 }))
      .toEqual({ lat: 23.81, lng: 90.41 });
    expect((service as any).parseSiteLocation({ siteLatitude: null, siteLongitude: null },
      { siteLatitude: 23.81, siteLongitude: 90.41 }))
      .toEqual({ lat: null, lng: null });
    expect(() => (service as any).parseSiteLocation({ siteLatitude: 91, siteLongitude: 90 }))
      .toThrow(BadRequestException);
    expect(() => (service as any).parseSiteLocation({ siteLatitude: 23.81 }))
      .toThrow(BadRequestException);
  });

  describe('IDOR & Project Visibility', () => {
    it('throws ForbiddenException when a member attempts to access an unassigned project', async () => {
      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: 'proj-secret',
            project_code: 'PRJ-2026-001',
            name: 'Confidential ERP System',
            created_by: 'admin-id',
            revenues: [],
            team_members: ['member-allowed'],
          },
        ],
      });

      const unauthorizedMember = {
        id: 'member-unauthorized',
        role: 'project_member',
        assignedProjectIds: ['proj-other'],
      };

      await expect(service.findOne('proj-secret', unauthorizedMember)).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('allows main_admin to view any project across the organization', async () => {
      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: 'proj-secret',
            project_code: 'PRJ-2026-001',
            name: 'Confidential ERP System',
            created_by: 'someone-else',
            revenues: [],
            team_members: ['someone-else'],
          },
        ],
      });

      const adminUser = {
        id: 'admin-id',
        role: 'main_admin',
        assignedProjectIds: [],
      };

      const result = await service.findOne('proj-secret', adminUser);
      expect(result.id).toBe('proj-secret');
      expect(result.name).toBe('Confidential ERP System');
    });

    it('allows assigned team member to view their project', async () => {
      const memberId = 'member-assigned';
      mockDb.query.mockResolvedValueOnce({
        rows: [
          {
            id: 'proj-assigned',
            project_code: 'PRJ-2026-002',
            name: 'Field Survey Phase 2',
            created_by: 'mgr-id',
            revenues: [],
            team_members: [memberId],
          },
        ],
      });

      const memberUser = {
        id: memberId,
        role: 'project_member',
        assignedProjectIds: ['proj-assigned'],
      };

      const result = await service.findOne('proj-assigned', memberUser);
      expect(result.id).toBe('proj-assigned');
      expect(result.teamMemberIds).toContain(memberId);
    });
  });

  describe('Update Permissions', () => {
    it('throws ForbiddenException when an unassigned project manager attempts to update a project', async () => {
      jest.spyOn(service, 'findOne').mockResolvedValueOnce({
        id: 'proj-1',
        name: 'Project 1',
        teamMemberIds: ['mgr-assigned'],
      } as any);

      const unassignedManager = {
        id: 'mgr-other',
        role: 'project_manager',
        assignedProjectIds: ['proj-other'],
      };

      await expect(service.update('proj-1', { name: 'Hacked Name' }, unassignedManager)).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('does not treat a Manager role title as project edit permission', async () => {
      jest.spyOn(service, 'findOne').mockResolvedValue({
        id: 'proj-1', name: 'Project 1', teamMemberIds: ['member-manager'],
      } as any);
      mockDb.query.mockResolvedValueOnce({ rows: [{ can_edit_project: false, role_in_project: 'Manager' }] });

      await expect(service.update('proj-1', { name: 'Changed' }, {
        id: 'member-manager', role: 'project_member',
      })).rejects.toThrow(ForbiddenException);
    });
  });

  describe('Project member access management', () => {
    it('rejects reading project member permissions for an unrelated authenticated user', async () => {
      mockDb.query.mockResolvedValueOnce({
        rows: [{ id: 'proj-private', created_by: 'creator-id' }],
      });

      await expect(
        (service.getProjectMembers as any)('proj-private', {
          id: 'outsider-id',
          role: 'project_member',
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('prevents a delegated team manager from granting permissions they do not hold', async () => {
      mockDb.query.mockImplementation(async (sql: string) => {
        if (sql.includes('SELECT id, name, created_by FROM projects')) {
          return { rows: [{ id: 'proj-private', name: 'VAL_Access Review', created_by: 'creator-id' }] };
        }
        if (sql.includes('can_manage_team')) {
          return {
            rows: [{
              can_manage_team: true,
              can_view_budget: false,
              can_record_revenue: false,
              can_view_expenses: true,
              can_create_expenses: true,
              can_approve_expenses: false,
              can_manage_tasks: true,
              can_update_progress: true,
              can_edit_project: false,
              can_view_attendance: true,
            }],
          };
        }
        if (sql.includes('FROM users WHERE id::text = $1')) return { rows: [{ role: 'project_member' }] };
        return { rows: [] };
      });

      await expect(
        service.addOrUpdateProjectMember(
          'proj-private',
          {
            userId: '11111111-1111-4111-8111-111111111111',
            roleInProject: 'Auditor',
            permissions: { canApproveExpenses: true },
          },
          { id: 'team-manager-id', role: 'project_member' },
        ),
      ).rejects.toThrow(ForbiddenException);
      expect(mockDb.query).not.toHaveBeenCalledWith(expect.stringContaining('INSERT INTO project_members'), expect.anything());
    });

    it('preserves existing target permissions when a delegated manager submits a partial update', async () => {
      let memberPermissionReads = 0;
      mockDb.query.mockImplementation(async (sql: string) => {
        if (sql.includes('SELECT id, name, created_by FROM projects')) return { rows: [{ id: 'proj-private', name: 'VAL_Access Review', created_by: 'creator-id' }] };
        if (sql.includes('FROM project_members WHERE project_id = $1 AND user_id = $2')) {
          memberPermissionReads += 1;
          if (memberPermissionReads % 2 === 1) return { rows: [{ can_manage_team: true, can_view_budget: false, can_record_revenue: false, can_view_expenses: true, can_create_expenses: true, can_approve_expenses: false, can_manage_tasks: true, can_update_progress: true, can_edit_project: false, can_view_attendance: true }] };
          return { rows: [{ can_view_budget: true, can_record_revenue: true, can_view_expenses: true, can_create_expenses: true, can_approve_expenses: true, can_manage_tasks: true, can_update_progress: true, can_manage_team: false, can_edit_project: false, can_view_attendance: true }] };
        }
        if (sql.includes('FROM users WHERE id::text = $1')) return { rows: [{ role: 'project_member' }] };
        if (sql.includes('INSERT INTO project_members')) return { rows: [] };
        if (sql.includes('FROM project_members pm')) return { rows: [] };
        return { rows: [] };
      });

      await service.addOrUpdateProjectMember('proj-private', {
        userId: '11111111-1111-4111-8111-111111111111', roleInProject: 'Auditor', permissions: {},
      }, { id: 'team-manager-id', role: 'project_member' });

      const insertCall = mockDb.query.mock.calls.find(([sql]) => sql.includes('INSERT INTO project_members'));
      expect(insertCall[1].slice(3)).toEqual([true, true, true, true, true, true, true, false, false, true]);
    });

    it('defaults a new delegated member to least privilege when permissions are omitted', async () => {
      let memberPermissionReads = 0;
      mockDb.query.mockImplementation(async (sql: string) => {
        if (sql.includes('SELECT id, name, created_by FROM projects')) return { rows: [{ id: 'proj-private', name: 'VAL_Access Review', created_by: 'creator-id' }] };
        if (sql.includes('FROM project_members WHERE project_id = $1 AND user_id = $2')) {
          memberPermissionReads += 1;
          return memberPermissionReads % 2 === 1
            ? { rows: [{ can_manage_team: true, can_view_budget: false, can_record_revenue: false, can_view_expenses: true, can_create_expenses: true, can_approve_expenses: false, can_manage_tasks: true, can_update_progress: true, can_edit_project: false, can_view_attendance: true }] }
            : { rows: [] };
        }
        if (sql.includes('FROM users WHERE id::text = $1')) return { rows: [{ role: 'project_member' }] };
        if (sql.includes('INSERT INTO project_members')) return { rows: [] };
        if (sql.includes('FROM project_members pm')) return { rows: [] };
        return { rows: [] };
      });

      await service.addOrUpdateProjectMember('proj-private', {
        userId: '11111111-1111-4111-8111-111111111111', roleInProject: 'Manager',
      }, { id: 'team-manager-id', role: 'project_member' });

      const insertCall = mockDb.query.mock.calls.find(([sql]) => sql.includes('INSERT INTO project_members'));
      expect(insertCall[1].slice(3)).toEqual(Array(10).fill(false));
    });
  });
});
