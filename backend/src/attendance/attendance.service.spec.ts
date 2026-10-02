import { AttendanceService } from './attendance.service';

describe('AttendanceService Unit & Session Logic', () => {
  let service: AttendanceService;
  let mockDb: any;

  beforeEach(() => {
    mockDb = {
      query: jest.fn().mockResolvedValue({ rows: [] }),
    };
    service = new AttendanceService(mockDb);
  });

  describe('checkIn', () => {
    it('creates attendance record for a valid check-in', async () => {
      const userId = 'user-emp-1';
      const checkInDto = {
        sessionType: 'morning' as const,
        latitude: 23.8103,
        longitude: 90.4125,
        addressText: 'Dhaka, Bangladesh',
        deviceInfo: 'Flutter Mobile App',
      };

      // Query 1: Check existing check-in -> none
      mockDb.query
        .mockResolvedValueOnce({ rows: [] })
        // Query 2: Insert returning id
        .mockResolvedValueOnce({
          rows: [{ id: 'att-rec-1' }],
        })
        // Query 3: getRecordById
        .mockResolvedValueOnce({
          rows: [
            {
              id: 'att-rec-1',
              user_id: userId,
              date: '2026-10-02',
              session_type: 'morning',
              login_time: new Date().toISOString(),
              latitude: '23.8103',
              longitude: '90.4125',
              address_text: 'Dhaka, Bangladesh',
              device_info: 'Flutter Mobile App',
              status: 'present',
              notes: '',
              created_at: new Date().toISOString(),
              full_name: 'Fahim Ahmed',
              email: 'fahim@pfis.com',
            },
          ],
        });

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

      // Query 1: Check existing -> found
      mockDb.query
        .mockResolvedValueOnce({
          rows: [{ id: 'existing-rec' }],
        })
        // Query 2: Update query
        .mockResolvedValueOnce({ rows: [] })
        // Query 3: getRecordById
        .mockResolvedValueOnce({
          rows: [
            {
              id: 'existing-rec',
              user_id: userId,
              date: '2026-10-02',
              session_type: 'morning',
              login_time: new Date().toISOString(),
              latitude: '23.8120',
              longitude: '90.4140',
              address_text: 'Updated Location, Dhaka',
              device_info: '',
              status: 'present',
              notes: '',
              created_at: new Date().toISOString(),
              full_name: 'Fahim Ahmed',
              email: 'fahim@pfis.com',
            },
          ],
        });

      const result = await service.checkIn(userId, checkInDto);
      expect(result.id).toBe('existing-rec');
      expect(result.latitude).toBe(23.8120);
    });
  });
});
