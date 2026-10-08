import { AttendanceService } from './attendance.service';

describe('AttendanceService Unit & Session Logic', () => {
  let service: AttendanceService;
  let mockDb: any;
  let mockNotifications: any;

  beforeEach(() => {
    mockDb = {
      query: jest.fn().mockResolvedValue({ rows: [] }),
    };
    mockNotifications = {
      create: jest.fn().mockResolvedValue({}),
    };
    const mockEmailService = {
      sendCheckInConfirmation: jest.fn().mockResolvedValue({}),
      sendNewExpenseNotification: jest.fn().mockResolvedValue({}),
    };
    service = new AttendanceService(mockDb, mockNotifications, mockEmailService as any);
  });

  describe('checkIn', () => {
    beforeEach(() => {
      // Mock user role query as employee ('employee')
      // and mock Date to 10:00 AM Dhaka time (UTC 04:00 AM)
      jest.useFakeTimers();
      jest.setSystemTime(new Date('2026-10-02T04:00:00.000Z')); // 10:00 AM in UTC+6
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    it('creates attendance record for a valid check-in', async () => {
      const userId = 'user-emp-1';
      const checkInDto = {
        sessionType: 'morning' as const,
        latitude: 23.8103,
        longitude: 90.4125,
        addressText: 'Dhaka, Bangladesh',
        deviceInfo: 'Flutter Mobile App',
      };

      // Query 0: getTimingSettings
      mockDb.query
        .mockResolvedValueOnce({ rows: [] })
      // Query 1: User role check
        .mockResolvedValueOnce({ rows: [{ role: 'employee', full_name: 'Fahim Ahmed', email: 'fahim@pfis.com' }] })
        // Query 2: Check existing check-in -> none
        .mockResolvedValueOnce({ rows: [] })
        // Query 3: Insert returning id
        .mockResolvedValueOnce({
          rows: [{ id: 'att-rec-1' }],
        })
        // Query 4: getRecordById
        .mockResolvedValueOnce({
          rows: [
            {
              id: 'att-rec-1',
              userId: userId,
              date: '2026-10-02',
              sessionType: 'morning',
              loginTime: new Date().toISOString(),
              latitude: 23.8103,
              longitude: 90.4125,
              addressText: 'Dhaka, Bangladesh',
              deviceInfo: 'Flutter Mobile App',
              status: 'present',
              notes: '',
              createdAt: new Date().toISOString(),
              userName: 'Fahim Ahmed',
              userEmail: 'fahim@pfis.com',
            },
          ],
        })
        // Query 5: user fullname + email query
        .mockResolvedValueOnce({ rows: [{ full_name: 'Fahim Ahmed', email: 'fahim@pfis.com' }] })
        // Query 6: get admins for push notification
        .mockResolvedValueOnce({ rows: [{ id: 'admin1' }] });

      const result = await service.checkIn(userId, checkInDto);
      expect(result.id).toBe('att-rec-1');
      expect(result.sessionType).toBe('morning');
      expect(result.status).toBe('present');
    });

    it('updates existing attendance check-in when checking in again for same session', async () => {
      const userId = 'user-emp-1';
      const checkInDto = {
        sessionType: 'morning' as const,
        latitude: 23.8120,
        longitude: 90.4140,
        addressText: 'Updated Location, Dhaka',
      };

      // Query 0: getTimingSettings
      mockDb.query
        .mockResolvedValueOnce({ rows: [] })
      // Query 1: User role check
        .mockResolvedValueOnce({ rows: [{ role: 'employee', full_name: 'Fahim Ahmed', email: 'fahim@pfis.com' }] })
        // Query 2: Check existing -> found
        .mockResolvedValueOnce({
          rows: [{ id: 'existing-rec' }],
        })
        // Query 3: Update query
        .mockResolvedValueOnce({ rows: [] })
        // Query 4: getRecordById
        .mockResolvedValueOnce({
          rows: [
            {
              id: 'existing-rec',
              userId: userId,
              date: '2026-10-02',
              sessionType: 'morning',
              loginTime: new Date().toISOString(),
              latitude: 23.8120,
              longitude: 90.4140,
              addressText: 'Updated Location, Dhaka',
              deviceInfo: '',
              status: 'present',
              notes: '',
              createdAt: new Date().toISOString(),
              userName: 'Fahim Ahmed',
              userEmail: 'fahim@pfis.com',
            },
          ],
        })
        // Query 5: user fullname + email query
        .mockResolvedValueOnce({ rows: [{ full_name: 'Fahim Ahmed', email: 'fahim@pfis.com' }] })
        // Query 6: get admins for push notification
        .mockResolvedValueOnce({ rows: [{ id: 'admin1' }] });

      const result = await service.checkIn(userId, checkInDto);
      expect(result.id).toBe('existing-rec');
      expect(result.latitude).toBe(23.8120);
    });
  });
});
