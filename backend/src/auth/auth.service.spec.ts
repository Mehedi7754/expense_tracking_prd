import { AuthService } from './auth.service';
import { BadRequestException } from '@nestjs/common';

describe('AuthService Password Reset & OTP Flow', () => {
  let service: AuthService;
  let mockDb: any;
  let mockJwt: any;
  let mockEmailService: any;

  beforeEach(() => {
    mockDb = {
      query: jest.fn().mockResolvedValue({ rows: [] }),
    };
    mockJwt = {
      sign: jest.fn().mockReturnValue('mock_jwt_token'),
    };
    mockEmailService = {
      sendPasswordResetOtp: jest.fn().mockResolvedValue(undefined),
      sendPasswordChangedConfirmation: jest.fn().mockResolvedValue(undefined),
    };

    service = new AuthService(mockDb, mockJwt, mockEmailService as any);
  });

  describe('forgotPassword', () => {
    it('dispatches 6-digit OTP email when user exists', async () => {
      mockDb.query
        // User lookup
        .mockResolvedValueOnce({
          rows: [{ id: 'u-123', full_name: 'Alvee Rahman', email: 'alvee@geospatialworks.com.bd' }],
        })
        // Invalidate old OTPs
        .mockResolvedValueOnce({ rows: [] })
        // Insert new OTP
        .mockResolvedValueOnce({ rows: [] })
        // Audit log
        .mockResolvedValueOnce({ rows: [] });

      const result = await service.forgotPassword('alvee@geospatialworks.com.bd');

      expect(result.success).toBe(true);
      expect(result.message).toContain('alvee@geospatialworks.com.bd');
      expect(mockEmailService.sendPasswordResetOtp).toHaveBeenCalledWith(
        'alvee@geospatialworks.com.bd',
        'Alvee Rahman',
        expect.stringMatching(/^\d{6}$/),
        15,
      );
      expect(mockDb.query).toHaveBeenCalledWith(
        expect.stringContaining('INSERT INTO password_resets'),
        expect.arrayContaining(['alvee@geospatialworks.com.bd']),
      );
    });

    it('returns generic success message when email is not found to prevent enumeration', async () => {
      mockDb.query.mockResolvedValueOnce({ rows: [] });

      const result = await service.forgotPassword('unknown@domain.com');

      expect(result.success).toBe(true);
      expect(mockEmailService.sendPasswordResetOtp).not.toHaveBeenCalled();
    });

    it('throws BadRequestException for invalid email format', async () => {
      await expect(service.forgotPassword('invalid-email')).rejects.toThrow(BadRequestException);
    });
  });

  describe('verifyOtp', () => {
    it('validates a valid, unexpired OTP successfully', async () => {
      mockDb.query.mockResolvedValueOnce({
        rows: [{ id: 'reset-1', expires_at: new Date(Date.now() + 600000).toISOString() }],
      });

      const result = await service.verifyOtp('alvee@geospatialworks.com.bd', '123456');

      expect(result.success).toBe(true);
      expect(result.valid).toBe(true);
    });

    it('throws BadRequestException for expired or incorrect OTP', async () => {
      mockDb.query.mockResolvedValueOnce({ rows: [] });

      await expect(service.verifyOtp('alvee@geospatialworks.com.bd', '000000')).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('resetPassword', () => {
    it('successfully resets password with valid OTP and sends confirmation email', async () => {
      mockDb.query
        // OTP check
        .mockResolvedValueOnce({ rows: [{ id: 'reset-1' }] })
        // User check
        .mockResolvedValueOnce({
          rows: [{ id: 'u-123', full_name: 'Alvee Rahman', email: 'alvee@geospatialworks.com.bd' }],
        })
        // Mark OTP used
        .mockResolvedValueOnce({ rows: [] })
        // Update user password
        .mockResolvedValueOnce({ rows: [] })
        // Audit log
        .mockResolvedValueOnce({ rows: [] });

      const result = await service.resetPassword('alvee@geospatialworks.com.bd', '123456', 'NewSecret123!');

      expect(result.success).toBe(true);
      expect(mockEmailService.sendPasswordChangedConfirmation).toHaveBeenCalledWith(
        'alvee@geospatialworks.com.bd',
        'Alvee Rahman',
      );
      expect(mockDb.query).toHaveBeenCalledWith(
        'UPDATE password_resets SET is_used = TRUE WHERE id = $1',
        ['reset-1'],
      );
      expect(mockDb.query).toHaveBeenCalledWith(
        expect.stringContaining('UPDATE users SET password_hash = $1'),
        expect.any(Array),
      );
    });

    it('throws BadRequestException if new password is too short', async () => {
      await expect(
        service.resetPassword('alvee@geospatialworks.com.bd', '123456', '123'),
      ).rejects.toThrow(BadRequestException);
    });

    it('throws BadRequestException if OTP is invalid or expired', async () => {
      mockDb.query.mockResolvedValueOnce({ rows: [] });

      await expect(
        service.resetPassword('alvee@geospatialworks.com.bd', '999999', 'NewSecret123!'),
      ).rejects.toThrow(BadRequestException);
    });
  });
});
