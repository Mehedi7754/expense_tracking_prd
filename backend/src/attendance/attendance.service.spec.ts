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

    it('throws ConflictException when checking in again for same session', async () => {
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
        });

      await expect(service.checkIn(userId, checkInDto)).rejects.toThrow(
        'You have already checked in for the morning session today.',
      );
    });

    it('creates attendance check-out record on time when checking out within grace period', async () => {
      // 17:50 Dhaka time (UTC 11:50) is within 15min grace period before 18:00 end
      jest.setSystemTime(new Date('2026-10-02T11:50:00.000Z'));

      const userId = 'user-emp-1';
      const checkInDto = {
        sessionType: 'afternoon' as const,
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
          rows: [{ id: 'att-rec-checkout' }],
        })
        // Query 4: getRecordById
        .mockResolvedValueOnce({
          rows: [
            {
              id: 'att-rec-checkout',
              userId: userId,
              date: '2026-10-02',
              sessionType: 'afternoon',
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
      expect(result.id).toBe('att-rec-checkout');
      expect(result.sessionType).toBe('afternoon');
      expect(mockNotifications.create).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Attendance Check-Out 📍',
          message: expect.stringContaining('check-out was successfully recorded'),
          type: 'attendance_reminder',
        }),
      );
      expect(mockNotifications.create).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Employee Checked Out: Fahim Ahmed (✅ ON TIME)',
          type: 'attendance_reminder',
        }),
      );
    });

    it('marks check-out as BEFORE TIME when leaving earlier than grace period threshold', async () => {
      // 16:30 Dhaka time (UTC 10:30) is earlier than (18:00 - 15m = 17:45)
      jest.setSystemTime(new Date('2026-10-02T10:30:00.000Z'));

      const userId = 'user-emp-1';
      const checkInDto = {
        sessionType: 'afternoon' as const,
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
          rows: [{ id: 'att-rec-early' }],
        })
        // Query 4: getRecordById
        .mockResolvedValueOnce({
          rows: [
            {
              id: 'att-rec-early',
              userId: userId,
              date: '2026-10-02',
              sessionType: 'afternoon',
              loginTime: new Date().toISOString(),
              latitude: 23.8103,
              longitude: 90.4125,
              addressText: 'Dhaka, Bangladesh',
              deviceInfo: 'Flutter Mobile App',
              status: 'present',
              notes: '[Checked out before time]',
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
      expect(result.id).toBe('att-rec-early');
      expect(result.sessionType).toBe('afternoon');

      // Verify DB insert recorded early checkout note
      expect(mockDb.query).toHaveBeenCalledWith(
        expect.stringContaining('INSERT INTO attendance_records'),
        expect.arrayContaining(['[Checked out before time]']),
      );

      // Verify employee notification has before-time title and attendance_early type
      expect(mockNotifications.create).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Attendance Check-Out (Before Time) ⚠️',
          message: expect.stringContaining('check-out was recorded before scheduled shift end'),
          type: 'attendance_early',
        }),
      );

      // Verify admin notification has before-time title and attendance_early type
      expect(mockNotifications.create).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Employee Checked Out: Fahim Ahmed (⚠️ BEFORE TIME)',
          type: 'attendance_early',
        }),
      );
    });
  });
});
