/**
 * Minimal CORS proxy for GitHub OAuth Device Flow endpoints.
 * Deploy with: wrangler deploy
 * This worker forwards only POST requests to two GitHub endpoints.
 */
const ALLOWED_PATHS = [
  '/login/device/code',
  '/login/oauth/access_token',
];

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return corsResponse(new Response(null, { status: 204 }));
    }
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    const url = new URL(request.url);
    if (!ALLOWED_PATHS.includes(url.pathname)) {
      return new Response('Not found', { status: 404 });
    }

    const target = 'https://github.com' + url.pathname;
    const body = await request.text();

    const upstream = await fetch(target, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
      body,
    });

    const text = await upstream.text();
    return corsResponse(new Response(text, {
      status: upstream.status,
      headers: { 'Content-Type': 'application/json' },
    }));
  },
};

function corsResponse(response) {
  const headers = new Headers(response.headers);
  headers.set('Access-Control-Allow-Origin', '*');
  headers.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  headers.set('Access-Control-Allow-Headers', 'Content-Type');
  return new Response(response.body, { status: response.status, headers });
}
