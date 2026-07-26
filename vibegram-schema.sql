-- VibeGram SQLite schema
-- Compatible with: SQLite, Turso / libSQL, Cloudflare D1
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  bio TEXT DEFAULT '',
  avatar TEXT DEFAULT '',
  password_hash TEXT NOT NULL,
  is_bot INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  last_seen INTEGER NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username ON users(username);

CREATE TABLE IF NOT EXISTS chats (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL CHECK(type IN ('dm','group','channel','saved')),
  title TEXT NOT NULL,
  username TEXT UNIQUE,
  about TEXT DEFAULT '',
  avatar TEXT DEFAULT '',
  is_public INTEGER DEFAULT 1,
  owner_id TEXT,
  comment_mode TEXT DEFAULT 'on',
  allowed_reactions TEXT DEFAULT '👍❤️🔥😢😡😮😂🎉',
  created_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_chats_username ON chats(username);
CREATE INDEX IF NOT EXISTS idx_chats_type ON chats(type);

CREATE TABLE IF NOT EXISTS chat_members (
  chat_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'member',
  can_send INTEGER DEFAULT 1,
  can_pin INTEGER DEFAULT 0,
  can_edit INTEGER DEFAULT 0,
  joined_at INTEGER NOT NULL,
  PRIMARY KEY(chat_id, user_id),
  FOREIGN KEY(chat_id) REFERENCES chats(id) ON DELETE CASCADE,
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,
  chat_id TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  reply_to TEXT,
  text TEXT NOT NULL,
  entities_json TEXT DEFAULT '[]',
  file_json TEXT,
  self_destruct_at INTEGER,
  scheduled_at INTEGER,
  edited_at INTEGER,
  created_at INTEGER NOT NULL,
  is_e2e INTEGER DEFAULT 0,
  FOREIGN KEY(chat_id) REFERENCES chats(id) ON DELETE CASCADE,
  FOREIGN KEY(sender_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(reply_to) REFERENCES messages(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_msg_chat_created ON messages(chat_id, created_at);
CREATE INDEX IF NOT EXISTS idx_msg_sender ON messages(sender_id);

CREATE TABLE IF NOT EXISTS reactions (
  message_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  emoji TEXT NOT NULL,
  PRIMARY KEY(message_id, user_id, emoji),
  FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE,
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bans (
  user_id TEXT NOT NULL,
  chat_id TEXT,
  reason TEXT,
  banned_by TEXT,
  banned_until INTEGER,
  is_shadow INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  PRIMARY KEY(user_id, chat_id),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS reports (
  id TEXT PRIMARY KEY,
  reporter_id TEXT NOT NULL,
  target_user_id TEXT,
  target_msg_id TEXT,
  reason TEXT NOT NULL,
  status TEXT DEFAULT 'open',
  created_at INTEGER NOT NULL,
  FOREIGN KEY(reporter_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS contacts (
  owner_id TEXT NOT NULL,
  contact_user_id TEXT NOT NULL,
  custom_name TEXT,
  PRIMARY KEY(owner_id, contact_user_id),
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(contact_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bots (
  owner_id TEXT NOT NULL,
  bot_user_id TEXT PRIMARY KEY,
  token TEXT NOT NULL,
  commands_json TEXT DEFAULT '[]',
  FOREIGN KEY(owner_id) REFERENCES users(id),
  FOREIGN KEY(bot_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS avatar_proposals (
  id TEXT PRIMARY KEY,
  from_user_id TEXT NOT NULL,
  to_user_id TEXT NOT NULL,
  avatar_data TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  created_at INTEGER NOT NULL
);

-- Seed bot users
INSERT OR IGNORE INTO users (id, username, name, bio, password_hash, is_bot, created_at, last_seen)
VALUES 
('u_bot_vg','vibegram','VibeGram','Официальный бот','sha:bot',1, strftime('%s','now')*1000, strftime('%s','now')*1000),
('u_bot_notes','notes','Заметки','Ваш личный бот','sha:bot',1, strftime('%s','now')*1000, strftime('%s','now')*1000);
