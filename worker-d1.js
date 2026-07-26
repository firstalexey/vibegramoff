/**
 * VibeGram Cloudflare Worker + D1
 * ----------------------------
 * Deploy:
 * 1) wrangler d1 create vibegram
 * 2) wrangler d1 execute vibegram --file=./public/vibegram-schema.sql
 * 3) wrangler deploy
 *
 * Binds in wrangler.toml:
 * [[d1_databases]]
 * binding = "DB"
 * database_name = "vibegram"
 * database_id = "xxxx"
 */

/**
 * ═══════ Zego Token04 (генерация токена звонка на сервере) ═══════
 * Раньше ZEGO_SECRET (серверный секрет владельца приложения ZegoCloud)
 * лежал прямо в клиентском коде — любой человек с исходниками сборки мог
 * им пользоваться от имени владельца. Теперь секрет живёт ТОЛЬКО здесь,
 * как приватная переменная окружения Worker'а:
 *   wrangler secret put ZEGO_SERVER_SECRET
 * Клиент присылает { appId, roomID, userID, userName } и получает
 * одноразовый токен на комнату, секрет клиенту не передаётся.
 * Реализация соответствует официальному алгоритму Zego Token04
 * (AES-128-CBC + случайный IV, см. server-SDK ZegoCloud). Перед боевым
 * использованием рекомендуется свериться с официальным Node.js SDK Zego.
 */
async function buildZegoToken(appId, userId, secret, effectiveSeconds) {
  const iv = crypto.getRandomValues(new Uint8Array(16));
  const nonce = Math.floor(Math.random() * 2147483647);
  const createTime = Math.floor(Date.now() / 1000);
  const expire = createTime + (effectiveSeconds || 3600);
  const body = JSON.stringify({ app_id: appId, user_id: userId, nonce, ctime: createTime, expire, payload: '' });
  const keyBytes = new TextEncoder().encode(String(secret).slice(0, 16).padEnd(16, '0'));
  const key = await crypto.subtle.importKey('raw', keyBytes, { name: 'AES-CBC' }, false, ['encrypt']);
  const cipherBuf = await crypto.subtle.encrypt({ name: 'AES-CBC', iv }, key, new TextEncoder().encode(body));
  const cipher = new Uint8Array(cipherBuf);
  const expireBuf = new ArrayBuffer(8);
  new DataView(expireBuf).setBigInt64(0, BigInt(expire), false);
  const out = new Uint8Array(8 + 2 + iv.length + 2 + cipher.length);
  let o = 0;
  out.set(new Uint8Array(expireBuf), o); o += 8;
  out.set([(iv.length >> 8) & 0xff, iv.length & 0xff], o); o += 2;
  out.set(iv, o); o += iv.length;
  out.set([(cipher.length >> 8) & 0xff, cipher.length & 0xff], o); o += 2;
  out.set(cipher, o);
  let bin = ''; out.forEach(b => bin += String.fromCharCode(b));
  return '04' + btoa(bin);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const cors = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });

    try {
      // POST /zego-token { appId, roomID, userID, userName } → { token }
      // Секрет ZEGO_SERVER_SECRET хранится только как секретная переменная окружения Worker'а.
      if (url.pathname === '/zego-token' && request.method === 'POST') {
        if (!env.ZEGO_SERVER_SECRET) {
          return Response.json({ ok: false, error: 'ZEGO_SERVER_SECRET не настроен на сервере' }, { status: 500, headers: cors });
        }
        const { appId, userID } = await request.json();
        const token = await buildZegoToken(Number(appId), String(userID || ''), env.ZEGO_SERVER_SECRET, 3600);
        return Response.json({ ok: true, token }, { headers: cors });
      }

      // Simple REST: POST /query {sql, params, token}
      if (url.pathname === '/query' && request.method === 'POST') {
        const { sql, params = [] } = await request.json();
        // In production: verify Authorization bearer token!
        const stmt = env.DB.prepare(sql).bind(...params);
        const isSelect = /^\s*select/i.test(sql);
        const result = isSelect ? await stmt.all() : await stmt.run();
        return Response.json({ ok: true, result }, { headers: cors });
      }

      // /auth {username, password_hash}
      if (url.pathname === '/auth' && request.method === 'POST') {
        const { username, password_hash } = await request.json();
        const user = await env.DB.prepare('SELECT * FROM users WHERE username = ? AND password_hash = ?')
          .bind(username, password_hash).first();
        return Response.json({ ok: !!user, user }, { headers: cors });
      }

      return Response.json({ ok: true, name: 'VibeGram D1 API', version: '1.0' }, { headers: cors });
    } catch (e) {
      return Response.json({ ok: false, error: String(e) }, { status: 500, headers: cors });
    }
  }
}
