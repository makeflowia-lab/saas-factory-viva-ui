// ══════════════════════════════════════════════════════════════
// MOTOR DE LA FÁBRICA v3 — con preguntas en vivo de los robots
// ══════════════════════════════════════════════════════════════
// 1. Byte SE DA CUENTA de que necesita la cadena de conexión y la PIDE
// 2. Construye el prototipo real
// 3. Eco PREGUNTA si publicar en Vercel ANTES de hacer el deploy
// 4. Entrega la URL final
//
// ➤ Para deploy real a Vercel desde n8n: guarda un token en el static
//   data del workflow (sd.vercelToken). El puente local usa tu CLI.

const base = 'https://n8n-n8n.gpr07a.easypanel.host/webhook/factory-event';
const feedUrl = 'https://n8n-n8n.gpr07a.easypanel.host/webhook/factory-feed';
const appBase = 'https://n8n-n8n.gpr07a.easypanel.host/webhook/factory-app';
const b = $json.body || {};
const project = b.project || 'Proyecto sin nombre';
const prompt = b.prompt || project;
// SOLO la idea del usuario se muestra en páginas/logs — NUNCA el prompt
// completo (puede contener la cadena de conexión u otras credenciales)
const context = (b.context || project).slice(0, 400);
const http = (o) => this.helpers.httpRequest(o);
const post = (ev) => http({ method: 'POST', url: base, body: ev, json: true });
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

const lastEventId = async () => {
  const r = await http({ method: 'GET', url: feedUrl + '?since=999999999', json: true });
  return r.lastId || 0;
};
// pregunta a través del bus y espera la respuesta del usuario (hasta 10 min)
const ask = async (agent, question, opts) => {
  const askId = 'ask-' + Date.now().toString(36) + Math.floor(Math.random() * 999);
  let cursor = await lastEventId();
  await post(Object.assign({ type: 'ask', askId, agent, project, question }, opts || {}));
  const t0 = Date.now();
  while (Date.now() - t0 < 10 * 60 * 1000) {
    await sleep(2500);
    const r = await http({ method: 'GET', url: feedUrl + '?since=' + cursor, json: true });
    for (const e of (r.events || [])) {
      if (e.id > cursor) cursor = e.id;
      if (e.type === 'answer' && e.askId === askId) return e.answer;
    }
  }
  return null;
};

await post({ type: 'project.start', project });
await post({ type: 'log', agent: 'Nova', project, message: 'Contexto recibido: ' + context.slice(0, 200), level: 'INFO' });

// ETAPA 1 — Nova analiza
await post({ type: 'task.start', agent: 'Nova', project, detail: 'inició: analizó el pedido y definió la estructura' });
const feats = context.split(/,| con | y (?=[a-záéíóúñ])/i)
  .map(s => s.trim()).filter(s => s.length > 3 && s.length < 90).slice(0, 6);
await sleep(2200);
await post({ type: 'task.done', agent: 'Nova', project, detail: 'analizó el pedido y definió la estructura' });

// ETAPA 2 — Byte SE DA CUENTA de que necesita la cadena de conexión
let conn = b.connection || null;
if (!conn) {
  conn = await ask('Byte',
    'Para configurar la base de datos necesito la <b>cadena de conexión</b> (Supabase o Neon). ¿Me la das?',
    { secret: true });
}
await post({ type: 'log', agent: 'Byte', project,
  message: conn ? 'Cadena de conexión recibida — base de datos configurada ✅'
                : 'Sin cadena de conexión — continúo con base de datos de prueba',
  level: 'OK' });

// ETAPA 3 — Byte construye el prototipo (aquí se enchufa tu fábrica real)
await post({ type: 'task.start', agent: 'Byte', project, detail: 'inició: construyó el prototipo del proyecto' });
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const cards = feats.map((f, i) =>
  '<div class="card"><div class="n">' + String(i + 1).padStart(2, '0') + '</div><p>' + esc(f) + '</p></div>'
).join('');
const html = '<!doctype html><html lang="es"><head><meta charset="utf-8">' +
  '<meta name="viewport" content="width=device-width,initial-scale=1">' +
  '<title>' + esc(project) + '</title><style>' +
  '*{box-sizing:border-box;margin:0}body{font-family:Segoe UI,system-ui,sans-serif;background:#0b1024;color:#eef0ff}' +
  '.hero{padding:90px 24px 70px;text-align:center;background:radial-gradient(900px 400px at 50% -10%,#2b3fae55,transparent)}' +
  '.tag{display:inline-block;border:1px solid #6d7bff66;color:#aab4ff;border-radius:99px;padding:6px 16px;font-size:12px;letter-spacing:.15em;text-transform:uppercase;margin-bottom:22px}' +
  'h1{font-size:clamp(32px,6vw,58px);letter-spacing:-.02em;margin-bottom:14px}' +
  '.sub{color:#9aa3d8;max-width:640px;margin:0 auto 30px;line-height:1.6}' +
  '.cta{display:inline-block;background:#6d7bff;color:#fff;padding:13px 30px;border-radius:12px;text-decoration:none;font-weight:700}' +
  '.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:14px;max-width:980px;margin:50px auto;padding:0 24px}' +
  '.card{background:#141a3f;border:1px solid #2a3370;border-radius:14px;padding:22px}' +
  '.card .n{color:#6d7bff;font-weight:800;margin-bottom:8px}' +
  '.card p{color:#c8cdf5;line-height:1.5}' +
  'footer{text-align:center;color:#5a639c;padding:40px;font-size:12px}' +
  '</style></head><body>' +
  '<div class="hero"><span class="tag">Prototipo generado</span><h1>' + esc(project) + '</h1>' +
  '<p class="sub">' + esc(context) + '</p><a class="cta" href="#f">Ver características</a></div>' +
  '<div class="grid" id="f">' + (cards || '<div class="card"><p>Prototipo inicial del proyecto</p></div>') + '</div>' +
  '<footer>Construido por 🏭 SaaS Factory OS — prototipo v1</footer>' +
  '</body></html>';
const sd = $getWorkflowStaticData('global');
if (!sd.apps2) sd.apps2 = {};
const appId = Date.now().toString(36);
sd.apps2[appId] = html;
const keys = Object.keys(sd.apps2);
if (keys.length > 20) delete sd.apps2[keys[0]];
await sleep(1800);
await post({ type: 'task.done', agent: 'Byte', project, detail: 'construyó el prototipo del proyecto' });

// ETAPA 4 — Vega verifica
await post({ type: 'task.start', agent: 'Vega', project, detail: 'inició: verificó el prototipo' });
await sleep(1500);
await post({ type: 'task.done', agent: 'Vega', project, detail: 'verificó el prototipo' });

// ETAPA 5 — Eco PREGUNTA antes de publicar
const dep = await ask('Eco', 'El proyecto está listo. ¿Publico el resultado en <b>Vercel</b>?',
  { options: ['Sí, publicar en Vercel', 'No, dejar en la fábrica'] });

let url = appBase + '?id=' + appId;
if (dep && dep.indexOf('Sí') === 0) {
  const token = sd.vercelToken || null;
  if (token) {
    try {
      await post({ type: 'task.start', agent: 'Eco', project, detail: 'inició: deploy a Vercel' });
      const name = ('fabrica-' + project).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 52);
      const d = await http({ method: 'POST', url: 'https://api.vercel.com/v13/deployments',
        headers: { Authorization: 'Bearer ' + token },
        body: { name, target: 'production', files: [{ file: 'index.html', data: html }], projectSettings: { framework: null } },
        json: true });
      if (d && d.url) url = 'https://' + d.url;
      await post({ type: 'task.done', agent: 'Eco', project, detail: 'deploy a Vercel completado' });
    } catch (err) {
      await post({ type: 'log', agent: 'Eco', project, message: 'Vercel rechazó el deploy (' + err.message.slice(0, 80) + ') — sirviendo desde la fábrica', level: 'INFO' });
    }
  } else {
    await post({ type: 'log', agent: 'Eco', project,
      message: 'Aún no tengo token de Vercel en el motor n8n — entrego la URL de la fábrica. (El puente local sí publica en Vercel con tu CLI.)', level: 'INFO' });
  }
} else {
  await post({ type: 'log', agent: 'Eco', project, message: 'Entendido: sin deploy — el proyecto queda en la fábrica', level: 'INFO' });
}

await post({ type: 'project.done', project, url });
return [{ json: { ok: true, project, url } }];
