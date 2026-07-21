const sd = $getWorkflowStaticData('global');
if (!Array.isArray(sd.events)) sd.events = [];
const b = $json.body || {};
const ev = {
  id: (sd.lastId = (sd.lastId || 0) + 1),
  type: b.type || 'log',
  agent: b.agent ?? null,
  project: b.project || b.name || null,
  detail: b.detail || b.message || '',
  level: b.level || 'INFO',
  url: b.url || null,
  askId: b.askId || null,
  question: b.question || null,
  options: Array.isArray(b.options) ? b.options : null,
  secret: !!b.secret,
  answer: (b.answer === undefined) ? null : b.answer,
  ts: new Date().toISOString()
};
sd.events.push(ev);
if (sd.events.length > 400) sd.events.splice(0, sd.events.length - 400);
return [{ json: { ok: true, id: ev.id, type: ev.type } }];
