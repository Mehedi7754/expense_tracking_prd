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
    service = new ProjectsService(mockDb, mockAudit, mockNotifications as any);
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
  });
});
