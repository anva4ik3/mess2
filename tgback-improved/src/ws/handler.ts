import { WebSocket, WebSocketServer } from 'ws';
import jwt from 'jsonwebtoken';
import { query } from '../db';

interface AuthenticatedWS extends WebSocket {
  userId?: string;
  chatIds?: Set<string>;
  isAlive?: boolean;
}

// userId -> Set of WebSocket connections
export const clients = new Map<string, Set<AuthenticatedWS>>();

export function setupWebSocket(wss: WebSocketServer) {
  // Heartbeat interval to detect dead connections
  const heartbeat = setInterval(() => {
    wss.clients.forEach((ws: AuthenticatedWS) => {
      if (ws.isAlive === false) {
        handleDisconnect(ws);
        return ws.terminate();
      }
      ws.isAlive = false;
      ws.ping();
    });
  }, 30000);

  wss.on('close', () => clearInterval(heartbeat));

  wss.on('connection', async (ws: AuthenticatedWS, req) => {
    const url = new URL(req.url!, `http://localhost`);
    const token = url.searchParams.get('token');

    if (!token) {
      ws.close(1008, 'Unauthorized');
      return;
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET!) as { userId: string };
      ws.userId = decoded.userId;
      ws.chatIds = new Set();
      ws.isAlive = true;

      if (!clients.has(ws.userId)) clients.set(ws.userId, new Set());
      clients.get(ws.userId)!.add(ws);

      // Отмечаем пользователя онлайн
      await setUserOnline(ws.userId, true);

      ws.send(JSON.stringify({ type: 'connected', userId: ws.userId }));

      // Рассылаем статус онлайн контактам
      await broadcastOnlineStatus(ws.userId, true);
    } catch {
      ws.close(1008, 'Invalid token');
      return;
    }

    ws.on('pong', () => { ws.isAlive = true; });

    ws.on('message', async (data) => {
      try {
        const msg = JSON.parse(data.toString());
        await handleMessage(ws, msg);
      } catch (err) {
        ws.send(JSON.stringify({ type: 'error', message: 'Неверный формат' }));
      }
    });

    ws.on('close', () => handleDisconnect(ws));
    ws.on('error', () => handleDisconnect(ws));
  });
}

async function handleDisconnect(ws: AuthenticatedWS) {
  if (!ws.userId) return;
  clients.get(ws.userId)?.delete(ws);
  if (clients.get(ws.userId)?.size === 0) {
    clients.delete(ws.userId);
    await setUserOnline(ws.userId, false);
    await broadcastOnlineStatus(ws.userId, false);
  }
}

async function setUserOnline(userId: string, online: boolean) {
  try {
    await query(
      'UPDATE users SET is_online = $1, last_seen_at = NOW() WHERE id = $2',
      [online, userId]
    );
  } catch (err) {
    console.error('setUserOnline error:', err);
  }
}

async function broadcastOnlineStatus(userId: string, isOnline: boolean) {
  try {
    // Найти все чаты пользователя и уведомить участников
    const chats = await query('SELECT chat_id FROM chat_members WHERE user_id = $1', [userId]);
    const sentTo = new Set<string>();

    for (const chat of chats.rows) {
      const members = await query('SELECT user_id FROM chat_members WHERE chat_id = $1', [chat.chat_id]);
      for (const member of members.rows) {
        if (member.user_id === userId || sentTo.has(member.user_id)) continue;
        sentTo.add(member.user_id);
        const userClients = clients.get(member.user_id);
        if (userClients) {
          for (const client of userClients) {
            if (client.readyState === WebSocket.OPEN) {
              client.send(JSON.stringify({ type: 'user_status', userId, isOnline, lastSeenAt: new Date().toISOString() }));
            }
          }
        }
      }
    }
  } catch (err) {
    console.error('broadcastOnlineStatus error:', err);
  }
}

async function handleMessage(ws: AuthenticatedWS, msg: any) {
  const { type, payload } = msg;

  switch (type) {
    case 'ping': {
      ws.send(JSON.stringify({ type: 'pong' }));
      break;
    }

    case 'join_chat': {
      const { chatId } = payload;
      const access = await query('SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2', [chatId, ws.userId]);
      if (access.rows.length > 0) {
        ws.chatIds!.add(chatId);
        ws.send(JSON.stringify({ type: 'joined_chat', chatId }));
      }
      break;
    }

    case 'leave_chat': {
      const { chatId } = payload;
      ws.chatIds!.delete(chatId);
      break;
    }

    case 'send_message': {
      const { chatId, content, replyTo, forwardFromChatId, forwardFromMessageId, forwardFromUser, type: msgType, mediaUrl } = payload;

      if (!ws.chatIds?.has(chatId)) {
        ws.send(JSON.stringify({ type: 'error', message: 'Сначала войдите в чат' }));
        return;
      }

      const result = await query(
        `INSERT INTO messages (chat_id, sender_id, content, reply_to, forward_from_chat_id, forward_from_message_id, forward_from_user, type, media_url) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
        [chatId, ws.userId, content, replyTo || null, forwardFromChatId || null, forwardFromMessageId || null, forwardFromUser || null, msgType || 'text', mediaUrl || null]
      );
      const messageRow = result.rows[0];

      const userResult = await query('SELECT username, display_name, avatar_url FROM users WHERE id = $1', [ws.userId]);
      const user = userResult.rows[0];

      let replyData = null;
      if (replyTo) {
        const replyMsg = await query(
          `SELECT m.content as reply_content, u.display_name as reply_sender FROM messages m JOIN users u ON u.id = m.sender_id WHERE m.id = $1`,
          [replyTo]
        );
        if (replyMsg.rows.length > 0) replyData = replyMsg.rows[0];
      }

      const outMessage = {
        type: 'new_message',
        message: {
          ...messageRow,
          username: user.username,
          display_name: user.display_name,
          avatar_url: user.avatar_url,
          reactions: [],
          ...(replyData || {}),
        },
      };

      await broadcastToChat(chatId, outMessage);
      break;
    }

    case 'typing': {
      const { chatId, isTyping } = payload;
      if (!ws.chatIds?.has(chatId)) return;

      const userResult = await query('SELECT display_name FROM users WHERE id = $1', [ws.userId]);
      const displayName = userResult.rows[0]?.display_name || 'Пользователь';

      await broadcastToChat(
        chatId,
        { type: 'typing', userId: ws.userId, displayName, isTyping },
        ws.userId
      );
      break;
    }

    case 'mark_read': {
      const { chatId } = payload;
      await query('UPDATE chat_members SET last_read_at = NOW() WHERE chat_id = $1 AND user_id = $2', [chatId, ws.userId]);
      // Уведомляем участников что прочитали
      await broadcastToChat(chatId, { type: 'messages_read', userId: ws.userId, chatId }, ws.userId);
      break;
    }

    case 'delete_message': {
      const { messageId, chatId } = payload;
      const msg = await query('SELECT sender_id FROM messages WHERE id = $1', [messageId]);
      if (msg.rows.length === 0) return;

      // Можно удалить своё сообщение или если admin/owner в группе
      const canDelete = msg.rows[0].sender_id === ws.userId;
      if (!canDelete) {
        const isAdmin = await query(
          `SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2 AND role IN ('owner','admin')`,
          [chatId, ws.userId]
        );
        if (isAdmin.rows.length === 0) {
          ws.send(JSON.stringify({ type: 'error', message: 'Нет прав для удаления' }));
          return;
        }
      }

      await query('UPDATE messages SET deleted_at = NOW() WHERE id = $1', [messageId]);
      await broadcastToChat(chatId, { type: 'message_deleted', messageId, chatId });
      break;
    }

    case 'edit_message': {
      const { messageId, chatId, content } = payload;
      const result = await query(
        `UPDATE messages SET content = $1, edited_at = NOW() WHERE id = $2 AND sender_id = $3 AND deleted_at IS NULL RETURNING *`,
        [content, messageId, ws.userId]
      );
      if (result.rows.length > 0) {
        await broadcastToChat(chatId, { type: 'message_edited', message: result.rows[0] });
      }
      break;
    }

    case 'react': {
      const { messageId, chatId, emoji } = payload;
      if (!ws.chatIds?.has(chatId)) return;

      const existing = await query(
        'SELECT id FROM message_reactions WHERE message_id = $1 AND user_id = $2 AND emoji = $3',
        [messageId, ws.userId, emoji]
      );

      if (existing.rows.length > 0) {
        await query('DELETE FROM message_reactions WHERE id = $1', [existing.rows[0].id]);
      } else {
        await query('INSERT INTO message_reactions (message_id, user_id, emoji) VALUES ($1, $2, $3)', [messageId, ws.userId, emoji]);
      }

      const reactions = await query(
        `SELECT emoji, json_agg(user_id) as users, COUNT(*) as count FROM message_reactions WHERE message_id = $1 GROUP BY emoji`,
        [messageId]
      );

      await broadcastToChat(chatId, { type: 'reaction_updated', messageId, reactions: reactions.rows });
      break;
    }
  }
}

async function broadcastToChat(chatId: string, data: any, excludeUserId?: string) {
  const members = await query('SELECT user_id FROM chat_members WHERE chat_id = $1', [chatId]);
  for (const member of members.rows) {
    if (member.user_id === excludeUserId) continue;
    const userClients = clients.get(member.user_id);
    if (userClients) {
      for (const client of userClients) {
        if (client.readyState === WebSocket.OPEN) {
          client.send(JSON.stringify(data));
        }
      }
    }
  }
}
