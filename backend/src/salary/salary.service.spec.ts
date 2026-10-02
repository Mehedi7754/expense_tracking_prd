import { SalaryService } from './salary.service';

describe('SalaryService Calculation & Workday Rules', () => {
  let service: SalaryService;
  let mockDb: any;

  beforeEach(() => {
    mockDb = {
      query: jest.fn().mockResolvedValue({ rows: [] }),
    };
    service = new SalaryService(mockDb);
  });

  describe('calculateSalary', () => {
    it('does not penalize or deduct salary for the in-progress workday (today)', async () => {
      const now = new Date();
      const currentYear = now.getFullYear();
      const currentMonth = now.getMonth() + 1;
      const todayIso = now.toISOString().split('T')[0];

      // Mock user salary profile
      mockDb.query
        .mockResolvedValueOnce({
          rows: [
            {
              id: 'sal-1',
              user_id: 'user-1',
              monthly_salary: '50000.00',
              currency: 'BDT',
              standard_working_days: 22,
              user_name: 'Fahim Ahmed',
              email: 'fahim@pfis.com',
              department: 'Operations',
              designation: 'Field Lead',
            },
          ],
        }); // default mockResolvedValue({ rows: [] }) handles holidays, leaves, records, adjustments, calculations

      const result = await service.calculateSalary('user-1', currentMonth, currentYear);

      const todayItem = result.dailyBreakdown.find((d) => d.date === todayIso);
      expect(todayItem).toBeDefined();

      if (todayItem && !todayItem.isWeekend && !todayItem.isHoliday) {
        expect(todayItem.status).toBe('upcoming');
        expect(todayItem.deductionUnits).toBe(0.0);
        expect(todayItem.notes).toContain('in progress');
      }
    });

    it('classifies Friday and Saturday as weekend non-working days with zero deduction', async () => {
      // October 2026: Oct 2 is Friday, Oct 3 is Saturday
      mockDb.query
        .mockResolvedValueOnce({
          rows: [
            {
              id: 'sal-1',
              user_id: 'user-1',
              monthly_salary: '44000.00',
              currency: 'BDT',
              standard_working_days: 22,
              user_name: 'Fahim Ahmed',
              email: 'fahim@pfis.com',
            },
          ],
        });

      const result = await service.calculateSalary('user-1', 10, 2026);

      const fridayItem = result.dailyBreakdown.find((d) => d.date === '2026-10-02');
      const saturdayItem = result.dailyBreakdown.find((d) => d.date === '2026-10-03');

      expect(fridayItem).toBeDefined();
      expect(fridayItem?.isWeekend).toBe(true);
      expect(fridayItem?.status).toBe('weekend');
      expect(fridayItem?.deductionUnits).toBe(0.0);

      expect(saturdayItem).toBeDefined();
      expect(saturdayItem?.isWeekend).toBe(true);
      expect(saturdayItem?.status).toBe('weekend');
      expect(saturdayItem?.deductionUnits).toBe(0.0);
    });

    it('identifies official holidays and applies zero absence penalty', async () => {
      // Mock salary profile then holiday on 2026-10-05
      mockDb.query
        .mockResolvedValueOnce({
          rows: [
            {
              id: 'sal-1',
              user_id: 'user-1',
              monthly_salary: '55000.00',
              currency: 'BDT',
              standard_working_days: 22,
              user_name: 'Fahim Ahmed',
            },
          ],
        })
        .mockResolvedValueOnce({
          rows: [
            {
              id: 'h-1',
              date: '2026-10-05',
              name: 'Company Foundation Day',
              is_recurring: false,
            },
          ],
        });

      const result = await service.calculateSalary('user-1', 10, 2026);

      const holidayItem = result.dailyBreakdown.find((d) => d.date === '2026-10-05');
      expect(holidayItem).toBeDefined();
      expect(holidayItem?.isHoliday).toBe(true);
      expect(holidayItem?.status).toBe('holiday');
      expect(holidayItem?.deductionUnits).toBe(0.0);
    });
  });
});
