import { Router, Response } from 'express';
import { query } from '../db';
import { authMiddleware, AuthRequest } from '../middleware/auth';
import { clients } from '../ws/handler';
import { WebSocket } from 'ws';

const router = Router();
router.use(authMiddleware);

// Все чаты пользователя
router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const result = await query(
      `SELECT c.*, 
        (SELECT m.content FROM messages m WHERE m.chat_id = c.id AND m.deleted_at IS NULL ORDER BY m.created_at DESC LIMIT 1) as last_message,
        (SELECT m.type FROM messages m WHERE m.chat_id = c.id AND m.deleted_at IS NULL ORDER BY m.created_at DESC LIMIT 1) as last_message_type,
        (SELECT m.created_at FROM messages m WHERE m.chat_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message_at,
        (SELECT m.sender_id FROM messages m WHERE m.chat_id = c.id AND m.deleted_at IS NULL ORDER BY m.created_at DESC LIMIT 1) as last_message_sender,
        (SELECT COUNT(*) FROM messages m WHERE m.chat_id = c.id AND m.sender_id != $1 AND m.deleted_at IS NULL AND m.created_at > 
          COALESCE((SELECT cm2.last_read_at FROM chat_members cm2 WHERE cm2.chat_id = c.id AND cm2.user_id = $1), '1970-01-01')) as unread_count,
        CASE WHEN c.type = 'direct' THEN 
          (SELECT u.display_name FROM users u JOIN chat_members cm ON cm.user_id = u.id WHERE cm.chat_id = c.id AND u.id != $1 LIMIT 1)
        ELSE c.name END as display_name,
        CASE WHEN c.type = 'direct' THEN 
          (SELECT u.avatar_url FROM users u JOIN chat_members cm ON cm.user_id = u.id WHERE cm.chat_id = c.id AND u.id != $1 LIMIT 1)
        ELSE c.avatar_url END as display_avatar,
        CASE WHEN c.type = 'direct' THEN 
          (SELECT u.id FROM users u JOIN chat_members cm ON cm.user_id = u.id WHERE cm.chat_id = c.id AND u.id != $1 LIMIT 1)
        ELSE NULL END as other_user_id,
        CASE WHEN c.type = 'direct' THEN 
          (SELECT u.is_online FROM users u JOIN chat_members cm ON cm.user_id = u.id WHERE cm.chat_id = c.id AND u.id != $1 LIMIT 1)
        ELSE NULL END as other_user_online,
        cm.is_muted
       FROM chats c
       JOIN chat_members cm ON cm.chat_id = c.id
       WHERE cm.user_id = $1
       ORDER BY last_message_at DESC NULLS LAST`,
      [req.userId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка загрузки чатов' });
  }
});

// Создать или открыть личный чат
router.post('/direct', async (req: AuthRequest, res: Response) => {
  try {
    const { targetUserId } = req.body;
    if (!targetUserId) return res.status(400).json({ error: 'targetUserId обязателен' });
    if (targetUserId === req.userId) return res.status(400).json({ error: 'Нельзя создать чат с собой' });

    const existing = await query(
      `SELECT c.id FROM chats c
       JOIN chat_members cm1 ON cm1.chat_id = c.id AND cm1.user_id = $1
       JOIN chat_members cm2 ON cm2.chat_id = c.id AND cm2.user_id = $2
       WHERE c.type = 'direct' LIMIT 1`,
      [req.userId, targetUserId]
    );

    if (existing.rows.length > 0) {
      return res.json({ chatId: existing.rows[0].id, existed: true });
    }

    const chatResult = await query(
      `INSERT INTO chats (type, created_by) VALUES ('direct', $1) RETURNING id`,
      [req.userId]
    );
    const chatId = chatResult.rows[0].id;
    await query(
      `INSERT INTO chat_members (chat_id, user_id, role) VALUES ($1, $2, 'member'), ($1, $3, 'member')`,
      [chatId, req.userId, targetUserId]
    );

    res.json({ chatId, existed: false });
  } catch (err) {
    res.status(500).json({ error: 'Ошибка создания чата' });
  }
});

// Создать группу
router.post('/group', async (req: AuthRequest, res: Response) => {
  try {
    const { name, memberIds, description } = req.body;
    if (!name) return res.status(400).json({ error: 'Название обязательно' });

    const chatResult = await query(
      `INSERT INTO chats (type, name, description, created_by) VALUES ('group', $1, $2, $3) RETURNING id`,
      [name, description || null, req.userId]
    );
    const chatId = chatResult.rows[0].id;

    const members = [req.userId, ...(memberIds || [])].filter(
      (v: string, i: number, a: string[]) => a.indexOf(v) === i
    );

    for (const memberId of members) {
      const role = memberId === req.userId ? 'owner' : 'member';
      await query(`INSERT INTO chat_members (chat_id, user_id, role) VALUES ($1, $2, $3)`, [chatId, memberId, role]);
    }

    res.json({ chatId });
  } catch (err) {
    res.status(500).json({ error: 'Ошибка создания группы' });
  }
});

// Информация о чате
router.get('/:chatId', async (req: AuthRequest, res: Response) => {
  try {
    const { chatId } = req.params;
    const access = await query('SELECT role FROM chat_members WHERE chat_id = $1 AND user_id = $2', [chatId, req.userId]);
    if (access.rows.length === 0) return res.status(403).json({ error: 'Нет доступа' });

    const chat = await query(`
      SELECT c.*,
        CASE WHEN c.type = 'direct' THEN 
          (SELECT u.display_name FROM users u JOIN chat_members cm ON cm.user_id = u.id WHERE cm.chat_id = c.id AND u.id != $2 LIMIT 1)
        ELSE c.name END as display_name,
        CASE WHEN c.type = 'direct' THEN 
          (SELECT u.avatar_url FROM users u JOIN chat_members cm ON cm.user_id = u.id WHERE cm.chat_id = c.id AND u.id != $2 LIMIT 1)
        ELSE c.avatar_url END as display_avatar,
        CASE WHEN c.type = 'direct' THEN 
          (SELECT u.is_online FROM users u JOIN chat_members cm ON cm.user_id = u.id WHERE cm.chat_id = c.id AND u.id != $2 LIMIT 1)
        ELSE NULL END as other_user_online,
        CASE WHEN c.type = 'direct' THEN 
          (SELECT u.last_seen_at FROM users u JOIN chat_members cm ON cm.user_id = u.id WHERE cm.chat_id = c.id AND u.id != $2 LIMIT 1)
        ELSE NULL END as other_last_seen,
        (SELECT COUNT(*) FROM chat_members WHERE chat_id = c.id) as members_count
      FROM chats c WHERE c.id = $1`, [chatId, req.userId]);

    res.json(chat.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка' });
  }
});

// Участники группы
router.get('/:chatId/members', async (req: AuthRequest, res: Response) => {
  try {
    const { chatId } = req.params;
    const access = await query('SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2', [chatId, req.userId]);
    if (access.rows.length === 0) return res.status(403).json({ error: 'Нет доступа' });

    const result = await query(
      `SELECT u.id, u.username, u.display_name, u.avatar_url, u.is_online, u.last_seen_at, cm.role
       FROM chat_members cm JOIN users u ON u.id = cm.user_id
       WHERE cm.chat_id = $1
       ORDER BY cm.role DESC, u.display_name`,
      [chatId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка' });
  }
});

// Добавить участника в группу
router.post('/:chatId/members', async (req: AuthRequest, res: Response) => {
  try {
    const { chatId } = req.params;
    const { userId } = req.body;
    const isAdmin = await query(
      `SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2 AND role IN ('owner','admin')`,
      [chatId, req.userId]
    );
    if (isAdmin.rows.length === 0) return res.status(403).json({ error: 'Нет прав' });

    await query(`INSERT INTO chat_members (chat_id, user_id, role) VALUES ($1, $2, 'member') ON CONFLICT DO NOTHING`, [chatId, userId]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Ошибка' });
  }
});

// Удалить участника из группы
router.delete('/:chatId/members/:userId', async (req: AuthRequest, res: Response) => {
  try {
    const { chatId, userId } = req.params;
    const isAdmin = await query(
      `SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2 AND role IN ('owner','admin')`,
      [chatId, req.userId]
    );
    const isSelf = userId === req.userId;
    if (!isSelf && isAdmin.rows.length === 0) return res.status(403).json({ error: 'Нет прав' });

    await query('DELETE FROM chat_members WHERE chat_id = $1 AND user_id = $2', [chatId, userId]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Ошибка' });
  }
});

// Сообщения чата (с пагинацией)
router.get('/:chatId/messages', async (req: AuthRequest, res: Response) => {
  try {
    const { chatId } = req.params;
    const { before, limit = 50 } = req.query;

    const access = await query('SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2', [chatId, req.userId]);
    if (access.rows.length === 0) return res.status(403).json({ error: 'Нет доступа' });

    let sql = `
      SELECT m.*, u.username, u.display_name, u.avatar_url, u.is_online,
        r.content as reply_content, ru.display_name as reply_sender,
        m.forward_from_user,
        COALESCE(
          json_agg(DISTINCT jsonb_build_object('emoji', mr.emoji, 'user_id', mr.user_id)) 
          FILTER (WHERE mr.id IS NOT NULL), '[]'
        ) as reactions
      FROM messages m
      JOIN users u ON u.id = m.sender_id
      LEFT JOIN messages r ON r.id = m.reply_to
      LEFT JOIN users ru ON ru.id = r.sender_id
      LEFT JOIN message_reactions mr ON mr.message_id = m.id
      WHERE m.chat_id = $1 AND m.deleted_at IS NULL
    `;
    const params: any[] = [chatId];

    if (before) {
      params.push(before);
      sql += ` AND m.created_at < $${params.length}`;
    }

    sql += ` GROUP BY m.id, u.username, u.display_name, u.avatar_url, u.is_online, r.content, ru.display_name`;
    sql += ` ORDER BY m.created_at DESC LIMIT $${params.length + 1}`;
    params.push(limit);

    const result = await query(sql, params);

    // Обновить last_read_at
    await query(`UPDATE chat_members SET last_read_at = NOW() WHERE chat_id = $1 AND user_id = $2`, [chatId, req.userId]);

    res.json(result.rows.reverse());
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка загрузки сообщений' });
  }
});

// Отправить сообщение (REST fallback)
router.post('/:chatId/messages', async (req: AuthRequest, res: Response) => {
  try {
    const { chatId } = req.params;
    const { content, replyTo, forwardFromChatId, forwardFromMessageId, forwardFromUser, mediaUrl, fileName, fileSize, type } = req.body;

    const access = await query('SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2', [chatId, req.userId]);
    if (access.rows.length === 0) return res.status(403).json({ error: 'Нет доступа' });

    const result = await query(
      `INSERT INTO messages (chat_id, sender_id, content, reply_to, forward_from_chat_id, forward_from_message_id, forward_from_user, media_url, file_name, file_size, type)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING *`,
      [chatId, req.userId, content, replyTo || null, forwardFromChatId || null, forwardFromMessageId || null, forwardFromUser || null, mediaUrl || null, fileName || null, fileSize || null, type || 'text']
    );

    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка отправки сообщения' });
  }
});

// Поиск сообщений в чате
router.get('/:chatId/search', async (req: AuthRequest, res: Response) => {
  try {
    const { chatId } = req.params;
    const { q } = req.query;
    if (!q || String(q).length < 2) return res.json([]);

    const access = await query('SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2', [chatId, req.userId]);
    if (access.rows.length === 0) return res.status(403).json({ error: 'Нет доступа' });

    const result = await query(
      `SELECT m.*, u.display_name, u.avatar_url
       FROM messages m JOIN users u ON u.id = m.sender_id
       WHERE m.chat_id = $1 AND m.deleted_at IS NULL AND m.content ILIKE $2
       ORDER BY m.created_at DESC LIMIT 30`,
      [chatId, `%${q}%`]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка поиска' });
  }
});

// Закрепить / открепить сообщение
router.post('/:chatId/messages/:messageId/pin', async (req: AuthRequest, res: Response) => {
  try {
    const { chatId, messageId } = req.params;
    const isAdmin = await query(
      `SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2 AND role IN ('owner','admin','member')`,
      [chatId, req.userId]
    );
    if (isAdmin.rows.length === 0) return res.status(403).json({ error: 'Нет доступа' });

    const msg = await query('SELECT is_pinned FROM messages WHERE id = $1 AND chat_id = $2', [messageId, chatId]);
    if (msg.rows.length === 0) return res.status(404).json({ error: 'Сообщение не найдено' });

    const nowPinned = !msg.rows[0].is_pinned;
    await query('UPDATE messages SET is_pinned = $1 WHERE id = $2', [nowPinned, messageId]);

    if (nowPinned) {
      await query('UPDATE chats SET pinned_message_id = $1 WHERE id = $2', [messageId, chatId]);
    } else {
      await query('UPDATE chats SET pinned_message_id = NULL WHERE id = $1', [chatId]);
    }

    broadcastToChat(chatId, { type: 'message_pinned', messageId, isPinned: nowPinned });

    res.json({ success: true, isPinned: nowPinned });
  } catch (err) {
    res.status(500).json({ error: 'Ошибка' });
  }
});

// Реакции на сообщение
router.post('/:chatId/messages/:messageId/react', async (req: AuthRequest, res: Response) => {
  try {
    const { chatId, messageId } = req.params;
    const { emoji } = req.body;
    if (!emoji) return res.status(400).json({ error: 'emoji обязателен' });

    const access = await query('SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2', [chatId, req.userId]);
    if (access.rows.length === 0) return res.status(403).json({ error: 'Нет доступа' });

    const existing = await query(
      'SELECT id FROM message_reactions WHERE message_id = $1 AND user_id = $2 AND emoji = $3',
      [messageId, req.userId, emoji]
    );

    let added: boolean;
    if (existing.rows.length > 0) {
      await query('DELETE FROM message_reactions WHERE id = $1', [existing.rows[0].id]);
      added = false;
    } else {
      await query('INSERT INTO message_reactions (message_id, user_id, emoji) VALUES ($1, $2, $3)', [messageId, req.userId, emoji]);
      added = true;
    }

    const reactions = await query(
      `SELECT emoji, json_agg(user_id) as users, COUNT(*) as count
       FROM message_reactions WHERE message_id = $1 GROUP BY emoji`,
      [messageId]
    );

    broadcastToChat(chatId, {
      type: 'reaction_updated',
      messageId,
      reactions: reactions.rows,
    });

    res.json({ success: true, added, reactions: reactions.rows });
  } catch (err) {
    res.status(500).json({ error: 'Ошибка реакции' });
  }
});

// Заглушить / Включить уведомления чата
router.post('/:chatId/mute', async (req: AuthRequest, res: Response) => {
  try {
    const { chatId } = req.params;
    const cm = await query('SELECT is_muted FROM chat_members WHERE chat_id = $1 AND user_id = $2', [chatId, req.userId]);
    if (cm.rows.length === 0) return res.status(403).json({ error: 'Нет доступа' });

    const newMuted = !cm.rows[0].is_muted;
    await query('UPDATE chat_members SET is_muted = $1 WHERE chat_id = $2 AND user_id = $3', [newMuted, chatId, req.userId]);
    res.json({ isMuted: newMuted });
  } catch (err) {
    res.status(500).json({ error: 'Ошибка' });
  }
});

// Поиск пользователей
router.get('/users/search', async (req: AuthRequest, res: Response) => {
  try {
    const { q } = req.query;
    if (!q || String(q).length < 2) return res.json([]);
    const result = await query(
      `SELECT id, username, display_name, avatar_url, is_online, last_seen_at FROM users 
       WHERE (username ILIKE $1 OR display_name ILIKE $1) AND id != $2 LIMIT 15`,
      [`%${q}%`, req.userId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка поиска' });
  }
});

async function broadcastToChat(chatId: string, data: any, excludeUserId?: string) {
  const members = await query('SELECT user_id FROM chat_members WHERE chat_id = $1', [chatId]);
  for (const member of members.rows) {
    if (member.user_id === excludeUserId) continue;
    const userClients = clients.get(member.user_id);
    if (userClients) {
      for (const client of userClients) {
        if ((client as any).readyState === WebSocket.OPEN) {
          client.send(JSON.stringify(data));
        }
      }
    }
  }
}

export default router;
