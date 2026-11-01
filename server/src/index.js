const http = require('http');
const express = require('express');
const { Server } = require('socket.io');
const config = require('./config');
const { RoomManager } = require('./rooms/RoomManager');
const { attachSockets } = require('./sockets');
const { connectDb } = require('./database');
const { privacyHtml } = require('./pages/privacy');

function createServer({ graceMs = config.graceMs } = {}) {
  const app = express();
  // `app` lets phones on the same Wi-Fi recognise this server when they search for it.
  app.get('/health', (_req, res) => res.json({ ok: true, app: 'party-games' }));
  app.get(['/privacy', '/privacy-policy'], (_req, res) => res.type('html').send(privacyHtml()));
  const httpServer = http.createServer(app);
  const io = new Server(httpServer, { cors: { origin: '*' } });
  const rooms = new RoomManager({ graceMs });
  attachSockets(io, rooms);
  const ticker = setInterval(() => rooms.tick(Date.now()), 250);
  ticker.unref();
  httpServer.on('close', () => { clearInterval(ticker); rooms.close(); });
  return { httpServer, io, rooms };
}
module.exports = { createServer };

if (require.main === module) {
  connectDb().catch(e => console.error('[db] failed', e.message)).finally(() => {
    createServer().httpServer.listen(config.port, () => {
      console.log(`server on :${config.port} (auth=${config.authMode})`);
      // The address to type into the app (Home > Server) on phones on the same Wi-Fi.
      const lan = Object.values(require('os').networkInterfaces()).flat()
        .filter(a => a && a.family === 'IPv4' && !a.internal).map(a => `${a.address}:${config.port}`);
      if (lan.length) console.log(`phones on the same Wi-Fi: enter ${lan.join(' or ')} under Home > Server`);
    });
  });
}
