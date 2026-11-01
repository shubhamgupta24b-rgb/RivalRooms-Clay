// Optional real-engine smoke test, using an existing desktop Chrome installation.
// This is not an Android WebView/device or multiplayer network test.
// Run from mobile/: node test/nitro_asset_smoke.cjs <absolute chrome executable>
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { mkdtempSync, rmSync, readFileSync } = require('node:fs');
const { createHash } = require('node:crypto');
const { tmpdir } = require('node:os');
const { resolve, join } = require('node:path');
const { pathToFileURL } = require('node:url');
const { validateSnapshot } = require('../../server/src/games/nitro_knockout');

const chromePath = process.argv[2];
assert(chromePath, 'Supply an existing Chrome executable');
const profile = mkdtempSync(join(tmpdir(), 'nitro-smoke-'));
const chrome = spawn(chromePath, ['--headless=new', '--no-first-run',
  '--no-default-browser-check', '--remote-debugging-pipe', '--enable-unsafe-swiftshader',
  '--use-angle=swiftshader', `--user-data-dir=${profile}`, 'about:blank'],
{ stdio: ['ignore', 'ignore', 'pipe', 'pipe', 'pipe'] });
let nextId = 0, buffer = '';
const pending = new Map();
const targets = new Map();
chrome.on('error', error => {
  for (const entry of pending.values()) entry.reject(error);
  pending.clear();
});
chrome.on('exit', code => {
  for (const entry of pending.values()) entry.reject(new Error(`Chrome exited (${code})`));
  pending.clear();
});
chrome.stderr.on('data', () => {});
chrome.stdio[4].on('data', data => {
  buffer += data.toString();
  for (let at; (at = buffer.indexOf('\0')) >= 0;) {
    const raw = buffer.slice(0, at); buffer = buffer.slice(at + 1);
    if (!raw) continue;
    const message = JSON.parse(raw);
    const entry = pending.get(message.id);
    if (entry) {
      pending.delete(message.id);
      message.error ? entry.reject(new Error(JSON.stringify(message.error))) : entry.resolve(message.result);
    }
  }
});
function command(method, params = {}, sessionId) {
  const id = ++nextId;
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    chrome.stdio[3].write(JSON.stringify({ id, method, params, sessionId }) + '\0');
  });
}
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function evaluate(session, expression) {
  const result = await command('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true }, session);
  if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
  return result.result.value;
}
async function page(boot) {
  const { targetId } = await command('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await command('Target.attachToTarget', { targetId, flatten: true });
  await command('Page.enable', {}, sessionId);
  await command('Page.navigate', { url: pathToFileURL(resolve('assets/nitro/index.html')).href }, sessionId);
  let booted = false;
  for (let i = 0; i < 250; i++) {
    const ready = await evaluate(sessionId, `!!window.__nitroBoot`);
    if (ready && !booted) {
      await evaluate(sessionId, `window.messages=[];window.NitroBridge={postMessage:m=>window.messages.push(JSON.parse(m))};window.__nitroBoot(${JSON.stringify(JSON.stringify(boot))});true`);
      booted = true;
    }
    if (booted && await evaluate(sessionId, '!!window.__nitroDebug')) {
      targets.set(sessionId, targetId);
      return sessionId;
    }
    await delay(100);
  }
  throw new Error(`Engine readiness timed out: ${await evaluate(sessionId, 'document.body.innerText')}`);
}
async function closePage(session) {
  await evaluate(session, 'window.__nitroDebug.dispose();true');
  await command('Target.closeTarget', { targetId: targets.get(session) });
  targets.delete(session);
}
async function waitFor(session, expression, description) {
  for (let i = 0; i < 100; i++) {
    if (await evaluate(session, expression)) return;
    await delay(100);
  }
  throw new Error(`Timed out: ${description}`);
}
async function assertRoster(session, mode, names, seat) {
  const stats = await evaluate(session, 'window.__nitroDebug.stats()');
  assert.equal(stats.net, mode);
  assert.equal(stats.seat, seat);
  assert.equal(stats.karts, names.length, 'Never fill an online room with extra bot karts');
  // Ka is the real engine instance in this pinned classic-script bundle. Read
  // its existing fields rather than extending the production debug API.
  const roster = await evaluate(session, '({names:Ka.karts.map(k=>k.name),seats:Ka.seatNames,local:Ka.karts.filter(k=>k.isPlayer).map(k=>k.id)})');
  assert.deepEqual(roster.names, names, 'Exact human names and seat order');
  assert.deepEqual(roster.seats, names);
  assert.deepEqual(roster.local, [seat], 'Only this page owns local controls; other online seats are remote humans, not AI');
}
const deadline = setTimeout(() => { console.error('Smoke test timed out'); chrome.kill(); process.exitCode = 1; }, 120000);
(async () => {
  try {
    const browser = await command('Browser.getVersion');
    console.log(`UTC ${new Date().toISOString()} | ${process.version} | ${process.platform}/${process.arch} | ${browser.product} | ${browser.jsVersion}`);
    console.log('Scope: real bundled engine from file URLs; desktop headless Chrome/SwiftShader. One host page plus one guest page per seat count; CDP relays messages locally. No Flutter WebView, Socket.IO, device, network, or performance claim.');
    for (const file of ['assets/nitro/index.html', 'assets/nitro/assets/index-CejRMBG2.js', 'assets/nitro/assets/index-CiJwpIAO.css']) {
      console.log(`SHA256 ${createHash('sha256').update(readFileSync(file)).digest('hex')} ${file}`);
    }
    const offline = await page({ mode: 'offline', seat: 0, seats: 8, names: [] });
    await evaluate(offline, 'window.__nitroDebug.start();true');
    assert.equal((await evaluate(offline, 'window.__nitroDebug.stats()')).karts, 8);
    assert.deepEqual(await evaluate(offline, 'Ka.karts.map(k=>k.name)'), ['YOU', 'NOVA', 'BOLT', 'ROOK', 'JINX', 'MISO', 'APEX', 'ECHO']);
    assert.deepEqual(await evaluate(offline, 'Ka.karts.filter(k=>k.isPlayer).map(k=>k.id)'), [0]);
    await evaluate(offline, 'window.__nitroDebug.pause();true');
    assert.equal((await evaluate(offline, 'window.__nitroDebug.stats()')).state, 'paused');
    await evaluate(offline, 'window.__nitroDebug.resume();window.__nitroDebug.audioSettings({music:false,sfx:true,volume:.2});true');
    await delay(300);
    await evaluate(offline, 'window.__nitroDebug.endMatch();true');
    assert.equal((await evaluate(offline, 'window.messages.filter(m=>m.kind==="result")')).length, 1);
    console.log('PASS file assets: offline 1 human + 7 named bots, 8-kart physics, start/pause/resume, result bridge');
    await closePage(offline);

    for (const seats of [2, 4, 8, 10]) {
      const names = Array.from({ length: seats }, (_, i) => `Human-${seats}-${i + 1}`);
      const guestSeat = seats - 1;
      const host = await page({ mode: 'host', seat: 0, seats, names, arena: 'foundry' });
      await assertRoster(host, 'host', names, 0);
      await evaluate(host, 'window.__nitroNet.start();true');
      await waitFor(host, 'window.messages.filter(m=>m.kind==="snapshot").length>=2', `${seats}-seat initial snapshots`);
      const initial = await evaluate(host, 'JSON.parse(window.messages.filter(m=>m.kind==="snapshot").at(-1).data)');
      validateSnapshot({ state: initial }, seats);

      const guest = await page({ mode: 'guest', seat: guestSeat, seats, names, arena: 'foundry' });
      await assertRoster(guest, 'guest', names, guestSeat);
      await evaluate(guest, `window.__nitroNet.snapshot(${JSON.stringify(JSON.stringify(initial))});true`);
      assert.equal((await evaluate(guest, 'window.__nitroDebug.stats()')).state, 'playing');
      await command('Page.bringToFront', {}, guest);
      await evaluate(guest, 'window.dispatchEvent(new KeyboardEvent("keydown",{code:"KeyW",key:"w",bubbles:true}));true');
      await waitFor(guest, 'window.messages.some(m=>m.kind==="input"&&m.args[0]>0)', `${seats}-seat real guest throttle message`);
      const input = await evaluate(guest, 'window.messages.filter(m=>m.kind==="input"&&m.args[0]>0).at(-1).args');
      await evaluate(guest, 'window.dispatchEvent(new KeyboardEvent("keyup",{code:"KeyW",key:"w",bubbles:true}));true');
      assert.equal(await evaluate(host, 'window.__nitroNet.input(0,[100,0,0,0])'), false, 'Reject host-local seat');
      assert.equal(await evaluate(host, `window.__nitroNet.input(${seats},[100,0,0,0])`), false, 'Reject nonexistent seat');
      const before = await evaluate(host, `Ka.karts[${guestSeat}].body.translation()`);
      assert.equal(await evaluate(host, `window.__nitroNet.input(${guestSeat},${JSON.stringify(input)})`), true);
      assert.equal(await evaluate(host, `Ka.seatInputs.get(${guestSeat}).throttle`), input[0]);
      await command('Page.bringToFront', {}, host);
      await waitFor(host, `Math.hypot(Ka.karts[${guestSeat}].body.translation().x-(${before.x}),Ka.karts[${guestSeat}].body.translation().z-(${before.z}))>0.25`, `${seats}-seat host-simulated guest planar movement`);
      const after = await evaluate(host, `Ka.karts[${guestSeat}].body.translation()`);
      const displacement = Math.hypot(after.x - before.x, after.z - before.z);
      await evaluate(host, 'window.__nitroDebug.eliminatePlayer();true');
      await waitFor(host, 'window.messages.some(m=>m.kind==="snapshot"&&JSON.parse(m.data).karts.some(k=>k[5]>0))', `${seats}-seat knockout score snapshot`);
      const live = await evaluate(host, 'window.messages.filter(m=>m.kind==="snapshot").map(m=>JSON.parse(m.data))');
      for (const frame of live) validateSnapshot({ state: frame }, seats);
      assert(live.at(-1).time < live[0].time, 'Physics match clock must advance');
      assert(live.every(frame => frame.seats === seats && frame.karts.length === seats));
      await assertRoster(host, 'host', names, 0);

      await evaluate(host, 'window.__nitroDebug.endMatch();true');
      const messages = await evaluate(host, 'window.messages');
      assert.equal(messages.filter(m => m.kind === 'finish').length, 1);
      const finish = messages.findIndex(m => m.kind === 'finish');
      assert(finish > 0);
      assert.equal(messages[finish - 1].kind, 'snapshot');
      const terminal = JSON.parse(messages[finish - 1].data);
      assert.equal(terminal.over, 1); assert.equal(terminal.time, 0);
      validateSnapshot({ state: terminal }, seats);
      const scores = terminal.karts.map(k => k[5]);
      assert.deepEqual(messages[finish].scores, scores);
      assert(scores.some(score => score > 0), 'Arena elimination must award a knockout');
      await evaluate(guest, `window.__nitroNet.snapshot(${JSON.stringify(JSON.stringify(terminal))});true`);
      assert.equal((await evaluate(guest, 'window.__nitroDebug.stats()')).state, 'gameover');
      assert.equal(await evaluate(guest, 'Ka.result.score'), scores[guestSeat]);
      assert.deepEqual(await evaluate(guest, 'Ka.lastSnapshot.karts.map(k=>k[5])'), scores);
      await assertRoster(guest, 'guest', names, guestSeat);
      assert(!messages.some(m => m.kind === 'engine_error'));
      assert.equal(await evaluate(guest, 'window.messages.some(m=>m.kind==="engine_error")'), false);
      console.log(`PASS ${seats} human seats: exact host/guest names+order, no bot filling; guest seat ${guestSeat} keyboard input applied, planar movement ${displacement.toFixed(3)} m; ${live.length} backend-valid live frames; knockout; terminal time=0/over=1 before finish; host finish and guest terminal scores=${JSON.stringify(scores)}`);
      await closePage(guest);
      await closePage(host);
    }
    console.log('PASS all requested rosters [2,4,8,10]. Matches deliberately ended through the existing debug API, not full 90-second endurance runs.');
  } finally {
    clearTimeout(deadline);
    chrome.kill();
    // Chrome can retain a profile handle briefly after termination on Windows.
    setTimeout(() => { try { rmSync(profile, { recursive: true, force: true }); } catch {} }, 500);
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
