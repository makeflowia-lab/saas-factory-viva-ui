export default {
  async fetch(request, env) {
    if (env.ASSETS) {
      const response = await env.ASSETS.fetch(request);
      if (response.status !== 404) {
        return response;
      }
    }
    return new Response("<!doctype html><html><head><meta http-equiv='refresh' content='0;url=/index.html'></head><body>Loading SaaS Factory UI...</body></html>", {
      headers: { "content-type": "text/html;charset=utf-8" }
    });
  }
};
