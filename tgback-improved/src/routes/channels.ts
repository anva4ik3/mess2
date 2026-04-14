import { Router, Response } from 'express';
import { query } from '../db';
import { authMiddleware, AuthRequest } from '../middleware/auth';

const router = Router();
router.use(authMiddleware);

// Создать канал
router.post('/', async (req: AuthRequest, res: Response) => {
  try {
    const { username, name, description, isPublic, monthlyPrice } = req.body;
    if (!username || !name) return res.status(400).json({ error: 'username и name обязательны' });

    const check = await query('SELECT id FROM channels WHERE username = $1', [username.toLowerCase()]);
    if (check.rows.length > 0) return res.status(400).json({ error: 'Username уже занят' });

    const result = await query(
      `INSERT INTO channels (owner_id, username, name, description, is_public, monthly_price)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [req.userId, username.toLowerCase(), name, description, isPublic ?? true, monthlyPrice ?? 0]
    );

    await query('INSERT INTO channel_subscribers (channel_id, user_id) VALUES ($1, $2)', [result.rows[0].id, req.userId]);
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка создания канала' });
  }
});

// Обзор каналов (публичные)
router.get('/explore', async (req: AuthRequest, res: Response) => {
  try {
    const { q } = req.query;
    let sql = `SELECT c.*, u.display_name as owner_name, u.avatar_url as owner_avatar,
      EXISTS(SELECT 1 FROM channel_subscribers WHERE channel_id = c.id AND user_id = $1) as is_subscribed,
      (SELECT cp.content FROM channel_posts cp WHERE cp.channel_id = c.id ORDER BY cp.created_at DESC LIMIT 1) as last_post
      FROM channels c JOIN users u ON u.id = c.owner_id
      WHERE c.is_public = true`;
    const params: any[] = [req.userId];

    if (q) {
      params.push(`%${q}%`);
      sql += ` AND (c.name ILIKE $${params.length} OR c.username ILIKE $${params.length})`;
    }

    sql += ' ORDER BY c.subscriber_count DESC LIMIT 50';
    const result = await query(sql, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка загрузки каналов' });
  }
});

// Мои подписки
router.get('/my', async (req: AuthRequest, res: Response) => {
  try {
    const result = await query(
      `SELECT c.*, u.display_name as owner_name,
        (SELECT cp.content FROM channel_posts cp WHERE cp.channel_id = c.id ORDER BY cp.created_at DESC LIMIT 1) as last_post,
        (SELECT cp.created_at FROM channel_posts cp WHERE cp.channel_id = c.id ORDER BY cp.created_at DESC LIMIT 1) as last_post_at,
        c.owner_id = $1 as is_owner, true as is_subscribed
       FROM channels c
       JOIN channel_subscribers cs ON cs.channel_id = c.id
       JOIN users u ON u.id = c.owner_id
       WHERE cs.user_id = $1
       ORDER BY last_post_at DESC NULLS LAST, c.name`,
      [req.userId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка' });
  }
});

// Канал по username
router.get('/:username', async (req: AuthRequest, res: Response) => {
  try {
    const result = await query(
      `SELECT c.*, u.display_name as owner_name, u.avatar_url as owner_avatar,
        EXISTS(SELECT 1 FROM channel_subscribers WHERE channel_id = c.id AND user_id = $2) as is_subscribed,
        c.owner_id = $2 as is_owner
       FROM channels c JOIN users u ON u.id = c.owner_id
       WHERE c.username = $1`,
      [req.params.username, req.userId]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Канал не найден' });
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка' });
  }
});

// Подписаться / отписаться
router.post('/:channelId/subscribe', async (req: AuthRequest, res: Response) => {
  try {
    const { channelId } = req.params;
    const existing = await query('SELECT 1 FROM channel_subscribers WHERE channel_id = $1 AND user_id = $2', [channelId, req.userId]);

    if (existing.rows.length > 0) {
      const isOwner = await query('SELECT 1 FROM channels WHERE id = $1 AND owner_id = $2', [channelId, req.userId]);
      if (isOwner.rows.length > 0) return res.status(400).json({ error: 'Владелец не может отписаться' });
      await query('DELETE FROM channel_subscribers WHERE channel_id = $1 AND user_id = $2', [channelId, req.userId]);
      await query('UPDATE channels SET subscriber_count = GREATEST(0, subscriber_count - 1) WHERE id = $1', [channelId]);
      res.json({ subscribed: false });
    } else {
      await query('INSERT INTO channel_subscribers (channel_id, user_id) VALUES ($1, $2)', [channelId, req.userId]);
      await query('UPDATE channels SET subscriber_count = subscriber_count + 1 WHERE id = $1', [channelId]);
      res.json({ subscribed: true });
    }
  } catch (err) {
    res.status(500).json({ error: 'Ошибка' });
  }
});

// Посты канала
router.get('/:channelId/posts', async (req: AuthRequest, res: Response) => {
  try {
    const { channelId } = req.params;
    const { before, limit = 20 } = req.query;

    const channel = await query('SELECT * FROM channels WHERE id = $1', [channelId]);
    if (channel.rows.length === 0) return res.status(404).json({ error: 'Не найдено' });

    const isSubscriber = await query('SELECT 1 FROM channel_subscribers WHERE channel_id = $1 AND user_id = $2', [channelId, req.userId]);
    const isOwner = channel.rows[0].owner_id === req.userId;
    const hasAccess = isOwner || isSubscriber.rows.length > 0;

    let sql = `SELECT * FROM channel_posts WHERE channel_id = $1 ${!hasAccess ? 'AND is_paid = false' : ''}`;
    const params: any[] = [channelId];

    if (before) {
      params.push(before);
      sql += ` AND created_at < $${params.length}`;
    }

    sql += ` ORDER BY created_at DESC LIMIT $${params.length + 1}`;
    params.push(limit);

    const result = await query(sql, params);

    // Обновляем счётчик просмотров
    if (result.rows.length > 0) {
      const ids = result.rows.map((r: any) => r.id);
      await query(`UPDATE channel_posts SET views = views + 1 WHERE id = ANY($1::uuid[])`, [ids]);
    }

    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка загрузки постов' });
  }
});

// Создать пост
router.post('/:channelId/posts', async (req: AuthRequest, res: Response) => {
  try {
    const { channelId } = req.params;
    const { content, mediaUrls, isPaid } = req.body;

    const channel = await query('SELECT * FROM channels WHERE id = $1 AND owner_id = $2', [channelId, req.userId]);
    if (channel.rows.length === 0) return res.status(403).json({ error: 'Нет прав' });

    const result = await query(
      `INSERT INTO channel_posts (channel_id, content, media_urls, is_paid) VALUES ($1, $2, $3, $4) RETURNING *`,
      [channelId, content, mediaUrls || [], isPaid ?? false]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка создания поста' });
  }
});

// Удалить пост
router.delete('/:channelId/posts/:postId', async (req: AuthRequest, res: Response) => {
  try {
    const { channelId, postId } = req.params;
    const channel = await query('SELECT 1 FROM channels WHERE id = $1 AND owner_id = $2', [channelId, req.userId]);
    if (channel.rows.length === 0) return res.status(403).json({ error: 'Нет прав' });
    await query('DELETE FROM channel_posts WHERE id = $1 AND channel_id = $2', [postId, channelId]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Ошибка' });
  }
});

// Донат
router.post('/:channelId/donate', async (req: AuthRequest, res: Response) => {
  try {
    const { channelId } = req.params;
    const { amount, message } = req.body;
    if (!amount || amount <= 0) return res.status(400).json({ error: 'Некорректная сумма' });

    await query(
      'INSERT INTO donations (from_user_id, to_channel_id, amount, message) VALUES ($1, $2, $3, $4)',
      [req.userId, channelId, amount, message]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Ошибка доната' });
  }
});

export default router;
