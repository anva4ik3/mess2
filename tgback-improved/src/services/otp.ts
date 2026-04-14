import { query } from '../db';
import nodemailer from 'nodemailer';

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.resend.com',
  port: parseInt(process.env.SMTP_PORT || '465'),
  secure: true,
  auth: {
    user: process.env.SMTP_USER || 'resend',
    pass: process.env.SMTP_PASS || '',
  },
});

export function generateOTP(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

export async function sendOTP(email: string): Promise<string> {
  const code = generateOTP();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

  await query('DELETE FROM otp_codes WHERE email = $1', [email]);
  await query(
    'INSERT INTO otp_codes (email, code, expires_at) VALUES ($1, $2, $3)',
    [email, code, expiresAt]
  );

  const smtpConfigured =
    process.env.SMTP_PASS && process.env.SMTP_PASS !== 're_your_api_key_here';

  if (smtpConfigured) {
    try {
      await transporter.sendMail({
        from: process.env.FROM_EMAIL || 'noreply@messenger.app',
        to: email,
        subject: 'Код подтверждения',
        html: `
          <div style="font-family: sans-serif; max-width: 400px; margin: 0 auto; padding: 20px;">
            <h2 style="color: #2AABEE;">Ваш код подтверждения</h2>
            <p style="font-size: 36px; font-weight: bold; letter-spacing: 8px; color: #1a1a2e; margin: 20px 0;">${code}</p>
            <p style="color: #666;">Код действителен 10 минут. Никому не сообщайте его.</p>
          </div>
        `,
      });
    } catch (err) {
      console.error('[OTP] Email send failed:', err);
    }
  }

  console.log(`[OTP] ${email} → ${code}`);
  return code;
}

export async function verifyOTP(email: string, code: string): Promise<boolean> {
  const result = await query(
    `SELECT id FROM otp_codes 
     WHERE email = $1 AND code = $2 AND expires_at > NOW() AND used = false
     LIMIT 1`,
    [email, code]
  );

  if (result.rows.length === 0) return false;

  await query('UPDATE otp_codes SET used = true WHERE id = $1', [result.rows[0].id]);
  return true;
}
