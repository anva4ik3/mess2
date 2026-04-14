import { Router, Response } from 'express';
import { query } from '../db';
import { authMiddleware, AuthRequest } from '../middleware/auth';

const router = Router();
router.use(authMiddleware);

// Все контакты пользователя
router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const result = await query(
      `SELECT c.id, c.nickname, c.created_at,
        u.id as user_id, u.username, u.display_name, u.avatar_url, u.bio, u.status_text,
        u.is_online, u.last_seen_at
       FROM contacts c JOIN users u ON u.id = c.contact_id
       WHERE c.user_id = $1
       ORDER BY u.display_name`,
      [req.userId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка загрузки контактов' });
  }
});

// Добавить контакт
router.post('/', async (req: AuthRequest, res: Response) => {
  try {
    const { contactId, nickname } = req.body;
    if (!contactId) return res.status(400).json({ error: 'contactId обязателен' });
    if (contactId === req.userId) return res.status(400).json({ error: 'Нельзя добавить себя' });

    const user = await query('SELECT id FROM users WHERE id = $1', [contactId]);
    if (user.rows.length === 0) return res.status(404).json({ error: 'Пользователь не найден' });

    await query(
      `INSERT INTO contacts (user_id, contact_id, nickname) VALUES ($1, $2, $3) ON CONFLICT (user_id, contact_id) DO UPDATE SET nickname = $3`,
      [req.userId, contactId, nickname || null]
    );

    const added = await query(
      `SELECT c.id, c.nickname, u.id as user_id, u.username, u.display_name, u.avatar_url, u.is_online
       FROM contacts c JOIN users u ON u.id = c.contact_id
       WHERE c.user_id = $1 AND c.contact_id = $2`,
      [req.userId, contactId]
    );

    res.json(added.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка добавления контакта' });
  }
});

// Удалить контакт
router.delete('/:contactId', async (req: AuthRequest, res: Response) => {
  try {
    await query('DELETE FROM contacts WHERE user_id = $1 AND contact_id = $2', [req.userId, req.params.contactId]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Ошибка' });
  }
});

// Проверить — в контактах ли
router.get('/check/:userId', async (req: AuthRequest, res: Response) => {
  try {
    const result = await query(
      'SELECT id FROM contacts WHERE user_id = $1 AND contact_id = $2',
      [req.userId, req.params.userId]
    );
    res.json({ isContact: result.rows.length > 0 });
  } catch (err) {
    res.status(500).json({ error: 'Ошибка' });
  }
});

export default router;
