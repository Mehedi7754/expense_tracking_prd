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

  async sendNewEmployeeRegisteredAlert(
    adminEmails: string[],
    employeeName: string,
    employeeEmail: string,
    department?: string,
    designation?: string,
  ) {
    if (!this.resend || !adminEmails.length) return;

    try {
      const from = this.fromEmail.includes('<') 
        ? this.fromEmail 
        : `GW Project Security <${this.fromEmail}>`;

      await this.resend.emails.send({
        from,
        to: adminEmails,
        subject: `New Employee Registration Awaiting Approval: ${employeeName}`,
        html: `
          <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 28px; background-color: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);">
            <div style="text-align: center; margin-bottom: 24px;">
              <h1 style="color: #1a365d; font-size: 24px; margin: 0; font-weight: 700;">Geospatial Works</h1>
              <p style="color: #718096; font-size: 13px; margin: 4px 0 0 0; text-transform: uppercase; letter-spacing: 1px;">Admin Action Required</p>
            </div>

            <div style="border-top: 2px solid #3182ce; padding-top: 20px;">
              <h2 style="color: #2d3748; font-size: 18px; margin-top: 0;">New Employee Awaiting Verification</h2>
              <p style="color: #4a5568; font-size: 15px; line-height: 1.6;">
                A new employee has submitted an account registration and requested mobile app & dashboard access. The account is currently <strong>Inactive / Pending Approval</strong>.
              </p>

              <table style="width: 100%; border-collapse: collapse; margin: 20px 0; background-color: #f7fafc; border-radius: 8px;">
                <tr>
                  <td style="padding: 12px; border-bottom: 1px solid #edf2f7; color: #718096; width: 35%;"><strong>Employee Name</strong></td>
                  <td style="padding: 12px; border-bottom: 1px solid #edf2f7; color: #2d3748; font-weight: 600;">${employeeName}</td>
                </tr>
                <tr>
                  <td style="padding: 12px; border-bottom: 1px solid #edf2f7; color: #718096;"><strong>Email Address</strong></td>
                  <td style="padding: 12px; border-bottom: 1px solid #edf2f7; color: #2d3748;">${employeeEmail}</td>
                </tr>
                <tr>
                  <td style="padding: 12px; border-bottom: 1px solid #edf2f7; color: #718096;"><strong>Department</strong></td>
                  <td style="padding: 12px; border-bottom: 1px solid #edf2f7; color: #2d3748;">${department || 'Not specified'}</td>
                </tr>
                <tr>
                  <td style="padding: 12px; color: #718096;"><strong>Designation</strong></td>
                  <td style="padding: 12px; color: #2d3748;">${designation || 'Not specified'}</td>
                </tr>
              </table>

              <div style="background-color: #ebf8ff; border-left: 4px solid #3182ce; padding: 14px 16px; margin: 20px 0; border-radius: 4px;">
                <p style="color: #2b6cb0; font-size: 14px; margin: 0; line-height: 1.5;">
                  <strong>Action Required:</strong> Please sign in to the Admin Dashboard or Mobile App and navigate to <strong>Employees / User Management</strong> to verify and approve this account.
                </p>
              </div>

              <p style="color: #718096; font-size: 13px; margin-top: 30px; text-align: center; border-top: 1px solid #edf2f7; padding-top: 20px;">
                Sent automatically to active system administrators.<br/>
                &copy; ${new Date().getFullYear()} Geospatial Works Ltd.
              </p>
            </div>
          </div>
        `,
      });
      this.logger.log(`Sent new employee alert to ${adminEmails.join(', ')}`);
    } catch (error) {
      this.logger.error(`Failed to send new employee alert to admins`, error);
    }
  }

  async sendEmployeeAccountApproved(
    employeeEmail: string,
    employeeName: string,
    appDownloadUrl: string,
  ) {
    if (!this.resend) return;

    try {
      const from = this.fromEmail.includes('<') 
        ? this.fromEmail 
        : `GW Project Security <${this.fromEmail}>`;

      await this.resend.emails.send({
        from,
        to: employeeEmail,
        subject: `Your Account Has Been Approved – Welcome to Geospatial Works`,
        html: `
          <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 28px; background-color: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);">
            <div style="text-align: center; margin-bottom: 24px;">
              <h1 style="color: #1a365d; font-size: 24px; margin: 0; font-weight: 700;">Geospatial Works</h1>
              <p style="color: #38a169; font-size: 13px; margin: 4px 0 0 0; text-transform: uppercase; letter-spacing: 1px; font-weight: 600;">Account Approved & Active</p>
            </div>

            <div style="border-top: 2px solid #38a169; padding-top: 20px;">
              <h2 style="color: #2d3748; font-size: 18px; margin-top: 0;">Welcome, ${employeeName}!</h2>
              <p style="color: #4a5568; font-size: 15px; line-height: 1.6;">
                Great news! Your Geospatial Works employee account has been verified and approved by the system administrator.
              </p>

              <div style="background-color: #f0fff4; border: 1px solid #c6f6d5; border-radius: 8px; padding: 18px; margin: 24px 0; text-align: center;">
                <p style="color: #22543d; font-size: 15px; margin: 0 0 16px 0; font-weight: 600;">
                  You now have full access to the Geospatial Works Mobile App & Web Portal.
                </p>
                <a href="${appDownloadUrl}" style="background-color: #2f855a; color: #ffffff; text-decoration: none; padding: 14px 28px; border-radius: 8px; font-weight: 700; font-size: 16px; display: inline-block; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                  📱 Download Mobile App (APK)
                </a>
              </div>

              <div style="background-color: #f7fafc; padding: 16px; border-radius: 8px; margin: 20px 0;">
                <p style="color: #4a5568; font-size: 14px; margin: 0 0 8px 0;"><strong>Your Account Details:</strong></p>
                <p style="color: #718096; font-size: 14px; margin: 4px 0;"><strong>Login Email:</strong> ${employeeEmail}</p>
                <p style="color: #718096; font-size: 14px; margin: 4px 0;"><strong>Status:</strong> <span style="color: #38a169; font-weight: 600;">Active & Verified</span></p>
              </div>

              <p style="color: #718096; font-size: 13px; line-height: 1.5;">
                To log in, open the downloaded mobile application or web portal and enter your registered email and password.
              </p>

              <p style="color: #718096; font-size: 13px; margin-top: 30px; text-align: center; border-top: 1px solid #edf2f7; padding-top: 20px;">
                This is an official automated notification from <strong>Geospatial Works</strong>.<br/>
                &copy; ${new Date().getFullYear()} Geospatial Works Ltd.
              </p>
            </div>
          </div>
        `,
      });
      this.logger.log(`Sent account approved confirmation to ${employeeEmail}`);
    } catch (error) {
      this.logger.error(`Failed to send account approval email to ${employeeEmail}`, error);
    }
  }

  async sendAdminLoginSecurityAlert(
    adminEmails: string[],
    userName: string,
    userEmail: string,
    userRole: string,
    loginTime: Date,
    ipAddress?: string,
  ) {
    if (!this.resend || !adminEmails.length) return;

    try {
      const from = this.fromEmail.includes('<') 
        ? this.fromEmail 
        : `GW Project Security <${this.fromEmail}>`;

      await this.resend.emails.send({
        from,
        to: adminEmails,
        subject: `Security Alert: User Login - ${userName} (${userEmail})`,
        html: `
          <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; background-color: #ffffff; border: 1px solid #e2e8f0; border-radius: 10px;">
            <div style="margin-bottom: 16px;">
              <h2 style="color: #2d3748; font-size: 17px; margin: 0;">🔐 User Login Notification</h2>
              <p style="color: #718096; font-size: 13px; margin: 4px 0 0 0;">System Security Audit Log</p>
            </div>

            <table style="width: 100%; border-collapse: collapse; margin: 16px 0; font-size: 14px;">
              <tr>
                <td style="padding: 8px 12px; background-color: #f7fafc; color: #718096; width: 30%;"><strong>User</strong></td>
                <td style="padding: 8px 12px; background-color: #f7fafc; color: #2d3748; font-weight: 600;">${userName}</td>
              </tr>
              <tr>
                <td style="padding: 8px 12px; color: #718096;"><strong>Email</strong></td>
                <td style="padding: 8px 12px; color: #2d3748;">${userEmail}</td>
              </tr>
              <tr>
                <td style="padding: 8px 12px; background-color: #f7fafc; color: #718096;"><strong>Role</strong></td>
                <td style="padding: 8px 12px; background-color: #f7fafc; color: #2d3748; text-transform: capitalize;">${userRole.replace('_', ' ')}</td>
              </tr>
              <tr>
                <td style="padding: 8px 12px; color: #718096;"><strong>Timestamp</strong></td>
                <td style="padding: 8px 12px; color: #2d3748;">${loginTime.toUTCString()}</td>
              </tr>
              ${ipAddress ? `
              <tr>
                <td style="padding: 8px 12px; background-color: #f7fafc; color: #718096;"><strong>IP Address</strong></td>
                <td style="padding: 8px 12px; background-color: #f7fafc; color: #2d3748; font-family: monospace;">${ipAddress}</td>
              </tr>` : ''}
            </table>

            <p style="color: #a0aec0; font-size: 12px; margin-top: 20px; text-align: center;">
              This alert was sent automatically to active system administrators.
            </p>
          </div>
        `,
      });
      this.logger.log(`Sent login security alert to ${adminEmails.length} admin(s) for ${userEmail}`);
    } catch (error) {
      this.logger.error(`Failed to send login security alert to admins`, error);
    }
  }
}


