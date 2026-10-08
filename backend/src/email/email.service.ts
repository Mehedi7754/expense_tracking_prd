import { Injectable, Logger } from '@nestjs/common';
import { Resend } from 'resend';

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private resend: Resend;
  private readonly fromEmail = process.env.EMAIL_FROM || 'notifications@yourdomain.com';

  constructor() {
    if (process.env.RESEND_API_KEY) {
      this.resend = new Resend(process.env.RESEND_API_KEY);
      this.logger.log('Resend Email Service initialized.');
    } else {
      this.logger.warn('RESEND_API_KEY is not set. Emails will not be sent.');
    }
  }

  async sendCheckInConfirmation(email: string, name: string, session: string, time: string, location: string, isLate: boolean) {
    if (!this.resend) return;

    try {
      const statusText = isLate ? 'marked as Late' : 'On Time';
      const statusColor = isLate ? '#e53e3e' : '#38a169'; // Red for late, Green for on time

      await this.resend.emails.send({
        from: `Attendance System <${this.fromEmail}>`,
        to: email,
        subject: `Attendance Confirmation: ${session.charAt(0).toUpperCase() + session.slice(1)} Session`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
            <h2 style="color: #2d3748; text-align: center;">Attendance Recorded Successfully</h2>
            <p style="color: #4a5568; font-size: 16px;">Hello <strong>${name}</strong>,</p>
            <p style="color: #4a5568; font-size: 16px;">Your check-in for the <strong>${session}</strong> session has been successfully recorded.</p>
            
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
}
