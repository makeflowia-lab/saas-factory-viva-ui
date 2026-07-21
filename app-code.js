const sd = $getWorkflowStaticData('global');
delete sd.apps; /* purga el almacén antiguo (contenía una página con credenciales) */
const id = ($json.query || {}).id;
const html = (sd.apps2 || {})[id] ||
  '<!doctype html><meta charset="utf-8"><body style="font-family:sans-serif;background:#0b1024;color:#eef0ff;display:grid;place-items:center;height:100vh;margin:0"><div style="text-align:center"><h1>Proyecto no encontrado</h1><p>El prototipo expiró o el ID es incorrecto.</p></div></body>';
return [{ json: { html } }];
