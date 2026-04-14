import { Router, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { query } from '../db';
import { sendOTP, verifyOTP } from '../services/otp';
import { authMiddleware, AuthRequest } from '../middleware/auth';

const router = Router();

// Отправка OTP
router.post('/send-otp', async (req: Request, res: Response) => {
  try {
    const { email } = req.body;
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return res.status(400).json({ error: 'Некорректный email' });
    }
    await sendOTP(email);
    res.json({ success: true, message: 'Код отправлен на почту' });
  } catch (err) {
    console.error('send-otp error:', err);
    res.status(500).json({ error: 'Ошибка отправки кода' });
  }
});

// Проверка OTP (возвращает isNewUser)
router.post('/verify-otp', async (req: Request, res: Response) => {
  try {
    const { email, code } = req.body;
    if (!email || !code) {
      return res.status(400).json({ error: 'Email и код обязательны' });
    }
    const valid = await verifyOTP(email, code);
    if (!valid) {
      return res.status(400).json({ error: 'Неверный или истёкший код' });
    }
    const userResult = await query('SELECT id FROM users WHERE email = $1', [email]);
    const isNewUser = userResult.rows.length === 0;

    if (!isNewUser) {
      const user = (await query('SELECT * FROM users WHERE email = $1', [email])).rows[0];
      const token = jwt.sign({ userId: user.id, email: user.email }, process.env.JWT_SECRET!, { expiresIn: '30d' });
      return res.json({ success: true, isNewUser: false, token, user: sanitizeUser(user) });
    }

    res.json({ success: true, isNewUser: true, email });
  } catch (err) {
    console.error('verify-otp error:', err);
    res.status(500).json({ error: 'Ошибка проверки кода' });
  }
});

// Регистрация нового пользователя
router.post('/register', async (req: Request, res: Response) => {
  try {
    const { email, username, displayName } = req.body;
    if (!email || !username) {
      return res.status(400).json({ error: 'Email и username обязательны' });
    }

    if (!/^[a-z0-9_]{3,30}$/.test(username.toLowerCase())) {
      return res.status(400).json({ error: 'Username: 3–30 символов, только буквы/цифры/подчёркивание' });
    }

    const usernameCheck = await query('SELECT id FROM users WHERE username = $1', [username.toLowerCase()]);
    if (usernameCheck.rows.length > 0) {
      return res.status(400).json({ error: 'Имя пользователя уже занято' });
    }

    const emailCheck = await query('SELECT id FROM users WHERE email = $1', [email]);
    if (emailCheck.rows.length > 0) {
      return res.status(400).json({ error: 'Email уже зарегистрирован' });
    }

    const result = await query(
      `INSERT INTO users (email, username, display_name, is_verified, is_online, last_seen_at) 
       VALUES ($1, $2, $3, true, true, NOW()) RETURNING *`,
      [email, username.toLowerCase(), displayName || username]
    );

    const user = result.rows[0];
    const token = jwt.sign({ userId: user.id, email: user.email }, process.env.JWT_SECRET!, { expiresIn: '30d' });
    res.json({ success: true, token, user: sanitizeUser(user) });
  } catch (err) {
    console.error('register error:', err);
    res.status(500).json({ error: 'Ошибка регистрации' });
  }
});

// Текущий пользователь
router.get('/me', authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const result = await query('SELECT * FROM users WHERE id = $1', [req.userId]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Пользователь не найден' });
    res.json(sanitizeUser(result.rows[0]));
  } catch (err) {
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

// Обновление профиля
router.patch('/me', authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const { displayName, bio, avatarUrl, statusText } = req.body;
    const result = await query(
      `UPDATE users SET 
        display_name = COALESCE($1, display_name),
        bio = COALESCE($2, bio),
        avatar_url = COALESCE($3, avatar_url),
        status_text = COALESCE($4, status_text)
       WHERE id = $5 RETURNING *`,
      [displayName, bio, avatarUrl, statusText, req.userId]
    );
    res.json(sanitizeUser(result.rows[0]));
  } catch (err) {
    res.status(500).json({ error: 'Ошибка обновления профиля' });
  }
});

// Поиск пользователей (глобальный)
router.get('/users/search', authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const { q } = req.query;
    if (!q || String(q).length < 2) return res.json([]);
    const result = await query(
      `SELECT id, username, display_name, avatar_url, is_online, last_seen_at, bio
       FROM users WHERE (username ILIKE $1 OR display_name ILIKE $1) AND id != $2 LIMIT 20`,
      [`%${q}%`, req.userId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка поиска' });
  }
});

// Профиль другого пользователя
router.get('/users/:userId', authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const result = await query(
      'SELECT id, username, display_name, avatar_url, bio, status_text, is_online, last_seen_at FROM users WHERE id = $1',
      [req.params.userId]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Не найден' });
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

function sanitizeUser(user: any) {
  const { ...safe } = user;
  return safe;
}

export default router;
