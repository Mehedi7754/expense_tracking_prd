import { Injectable, Logger } from '@nestjs/common';
import { Resend } from 'resend';

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private resend: Resend;
  private readonly fromEmail = process.env.EMAIL_FROM || process.env.RESEND_FROM || 'GW Project Security <security@geospatialworks.com.bd>';

  constructor() {
    if (process.env.RESEND_API_KEY) {
      this.resend = new Resend(process.env.RESEND_API_KEY);
      this.logger.log('Resend Email Service initialized.');
    } else {
      this.logger.warn('RESEND_API_KEY is not set. Emails will not be sent.');
    }
  }

  async sendCheckInConfirmation(
    email: string,
    name: string,
    session: string,
    time: string,
    location: string,
    isLate: boolean,
    isEarly: boolean = false,
  ) {
    if (!this.resend) return;

    try {
      const isCheckOut = session === 'afternoon';
      let statusText = isLate ? 'marked as Late' : 'On Time';
      let statusColor = isLate ? '#e53e3e' : '#38a169'; // Red for late, Green for on time

      if (isCheckOut) {
        if (isEarly) {
          statusText = 'Early Check-Out (Before Time)';
          statusColor = '#dd6b20'; // Amber/Orange
        } else {
          statusText = 'On Time Check-Out';
          statusColor = '#38a169'; // Green
        }
      }

      const subject = isCheckOut
        ? `Attendance Check-Out Confirmation${isEarly ? ' (Early Departure)' : ''}`
        : `Attendance Confirmation: ${session.charAt(0).toUpperCase() + session.slice(1)} Session`;

      await this.resend.emails.send({
        from: `Attendance System <${this.fromEmail}>`,
        to: email,
        subject,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
            <h2 style="color: #2d3748; text-align: center;">${isCheckOut ? 'Attendance Check-Out Recorded' : 'Attendance Recorded Successfully'}</h2>
            <p style="color: #4a5568; font-size: 16px;">Hello <strong>${name}</strong>,</p>
            <p style="color: #4a5568; font-size: 16px;">Your ${isCheckOut ? 'check-out' : 'check-in for the <strong>' + session + '</strong> session'} has been successfully recorded.</p>
            
            <div style="background-color: #f7fafc; padding: 15px; border-radius: 6px; margin: 20px 0;">
              <p style="margin: 5px 0; color: #4a5568;"><strong>Time:</strong> ${time}</p>
              <p style="margin: 5px 0; color: #4a5568;"><strong>Location:</strong> ${location}</p>
              <p style="margin: 5px 0; color: #4a5568;">
                <strong>Status:</strong> <span style="color: ${statusColor}; font-weight: bold;">${statusText}</span>
              </p>
            </div>
            
            <p style="color: #718096; font-size: 14px; text-align: center; margin-top: 30px;">
              This is an automated message. Please do not reply to this email.
            </p>
          </div>
        `,
      });
      this.logger.log(`Sent check-in email to ${email}`);
    } catch (error) {
      this.logger.error(`Failed to send check-in email to ${email}`, error);
    }
  }

  async sendNewExpenseNotification(email: string, submitterName: string, amount: number, currency: string, category: string, projectName: string) {
    if (!this.resend) return;

    try {
      await this.resend.emails.send({
        from: `Expense System <${this.fromEmail}>`,
        to: email,
        subject: `New Expense Submitted: ${category} by ${submitterName}`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
            <h2 style="color: #2d3748; border-bottom: 2px solid #3182ce; padding-bottom: 10px;">New Expense Submission</h2>
            
            <p style="color: #4a5568; font-size: 16px;">A new expense has been submitted by <strong>${submitterName}</strong> and requires your review.</p>
            
            <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
              <tr>
                <td style="padding: 10px; border-bottom: 1px solid #e2e8f0; color: #718096; width: 30%;"><strong>Amount</strong></td>
                <td style="padding: 10px; border-bottom: 1px solid #e2e8f0; color: #2d3748; font-weight: bold; font-size: 18px;">${amount.toFixed(2)} ${currency}</td>
              </tr>
              <tr>
                <td style="padding: 10px; border-bottom: 1px solid #e2e8f0; color: #718096;"><strong>Category</strong></td>
                <td style="padding: 10px; border-bottom: 1px solid #e2e8f0; color: #2d3748;">${category}</td>
              </tr>
              <tr>
                <td style="padding: 10px; border-bottom: 1px solid #e2e8f0; color: #718096;"><strong>Project</strong></td>
                <td style="padding: 10px; border-bottom: 1px solid #e2e8f0; color: #2d3748;">${projectName}</td>
              </tr>
            </table>
            
            <div style="text-align: center; margin-top: 30px;">
              <a href="#" style="background-color: #3182ce; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; font-weight: bold; display: inline-block;">Review in Admin Panel</a>
            </div>
            
            <p style="color: #718096; font-size: 14px; text-align: center; margin-top: 40px;">
              You received this email because of your administrative role.
            </p>
          </div>
        `,
      });
      this.logger.log(`Sent new expense email to ${email}`);
    } catch (error) {
      this.logger.error(`Failed to send new expense email to ${email}`, error);
    }
  }

  async sendPasswordResetOtp(email: string, name: string, otp: string, expiryMinutes: number = 15) {
    if (!this.resend) {
      this.logger.warn(`Resend not initialized. Password reset OTP for ${email}: ${otp}`);
      return;
    }

    try {
      const from = this.fromEmail.includes('<') 
        ? this.fromEmail 
        : `GW Project Security <${this.fromEmail}>`;

      await this.resend.emails.send({
        from,
        to: email,
        subject: `Password Reset Verification Code: ${otp}`,
        html: `
          <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 28px; background-color: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);">
            <div style="text-align: center; margin-bottom: 24px;">
              <h1 style="color: #1a365d; font-size: 24px; margin: 0; font-weight: 700; letter-spacing: -0.5px;">Geospatial Works</h1>
              <p style="color: #718096; font-size: 13px; margin: 4px 0 0 0; text-transform: uppercase; letter-spacing: 1px;">Enterprise Project & Financial Intelligence</p>
            </div>

            <div style="border-top: 2px solid #3182ce; padding-top: 20px;">
              <h2 style="color: #2d3748; font-size: 18px; margin-top: 0;">Password Reset Request</h2>
              <p style="color: #4a5568; font-size: 15px; line-height: 1.6;">Hello <strong>${name}</strong>,</p>
              <p style="color: #4a5568; font-size: 15px; line-height: 1.6;">We received a request to reset the password for your Geospatial Works account. Please use the following 6-digit verification code to complete your password reset:</p>

              <div style="background-color: #ebf8ff; border: 2px dashed #3182ce; border-radius: 8px; padding: 20px; text-align: center; margin: 24px 0;">
                <span style="font-size: 34px; font-weight: 800; letter-spacing: 8px; color: #2b6cb0; font-family: monospace;">${otp}</span>
                <p style="color: #4a5568; font-size: 13px; margin: 8px 0 0 0;">This code will expire in <strong>${expiryMinutes} minutes</strong>.</p>
              </div>

              <div style="background-color: #fffaf0; border-left: 4px solid #dd6b20; padding: 12px 16px; margin: 20px 0; border-radius: 4px;">
                <p style="color: #7b341e; font-size: 13px; margin: 0; line-height: 1.5;">
                  <strong>Security Reminder:</strong> If you did not request this password reset, please ignore this email or contact your IT security administrator immediately. Never share this code with anyone.
                </p>
              </div>

              <p style="color: #718096; font-size: 13px; margin-top: 30px; text-align: center; border-top: 1px solid #edf2f7; padding-top: 20px;">
                This is an automated security transmission from <strong>Geospatial Works Security Systems</strong>.<br/>
                &copy; ${new Date().getFullYear()} Geospatial Works Ltd. All rights reserved.
              </p>
            </div>
          </div>
        `,
      });
      this.logger.log(`Sent password reset OTP email to ${email}`);
    } catch (error) {
      this.logger.error(`Failed to send password reset OTP to ${email}`, error);
    }
  }

  async sendPasswordChangedConfirmation(email: string, name: string) {
    if (!this.resend) return;

    try {
      const from = this.fromEmail.includes('<') 
        ? this.fromEmail 
        : `GW Project Security <${this.fromEmail}>`;

      await this.resend.emails.send({
        from,
        to: email,
        subject: `Security Alert: Your Password Was Changed`,
        html: `
          <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 28px; background-color: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px;">
            <div style="text-align: center; margin-bottom: 24px;">
              <h1 style="color: #1a365d; font-size: 24px; margin: 0; font-weight: 700;">Geospatial Works</h1>
            </div>

            <div style="border-top: 2px solid #38a169; padding-top: 20px;">
              <h2 style="color: #2d3748; font-size: 18px; margin-top: 0;">Password Changed Successfully</h2>
              <p style="color: #4a5568; font-size: 15px;">Hello <strong>${name}</strong>,</p>
              <p style="color: #4a5568; font-size: 15px; line-height: 1.6;">
                The password for your account associated with <strong>${email}</strong> was successfully updated.
              </p>
              <p style="color: #4a5568; font-size: 15px; line-height: 1.6;">
                You can now log in using your newly configured credentials.
              </p>

              <div style="background-color: #f7fafc; padding: 14px 18px; border-radius: 6px; margin: 20px 0; color: #718096; font-size: 13px;">
                <strong>Time:</strong> ${new Date().toUTCString()}
              </div>

              <p style="color: #e53e3e; font-size: 13px; font-weight: 600;">
                If you did not make this change, please contact system administration immediately.
              </p>
            </div>
          </div>
        `,
      });
      this.logger.log(`Sent password changed confirmation email to ${email}`);
    } catch (error) {
      this.logger.error(`Failed to send password changed confirmation to ${email}`, error);
    }
  }
}

