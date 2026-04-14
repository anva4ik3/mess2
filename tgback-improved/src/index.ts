import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import dotenv from 'dotenv';
dotenv.config();

import { pool, runMigrations } from './db';
import { setupWebSocket } from './ws/handler';
import authRoutes from './routes/auth';
import chatsRoutes from './routes/chats';
import channelsRoutes from './routes/channels';
import aiRoutes from './routes/ai';
import contactsRoutes from './routes/contacts';

const app = express();
const server = createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  credentials: true,
}));
app.use(express.json({ limit: '50mb' }));

// Health check
app.get('/health', (_, res) => res.json({ ok: true, ts: new Date().toISOString() }));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/chats', chatsRoutes);
app.use('/api/channels', channelsRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/contacts', contactsRoutes);

// WebSocket
setupWebSocket(wss);

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, async () => {
  try {
    await pool.query('SELECT 1');
    console.log('✅ DB connected');
    await runMigrations();
  } catch (err) {
    console.error('❌ Startup error:', err);
    process.exit(1);
  }
  console.log(`🚀 Server running on port ${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('Shutting down...');
  server.close();
  await pool.end();
  process.exit(0);
});
