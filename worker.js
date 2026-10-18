/**
 * CodePlay Worker. The whole game is static, so every request is served straight
 * from the assets binding. SPA fallback keeps deep links working.
 */
export default {
  async fetch(request, env) {
    const response = await env.ASSETS.fetch(request);
    if (response.status === 404 && request.method === 'GET') {
      return env.ASSETS.fetch(new Request(new URL('/', request.url), request));
    }
    return response;
  },
};
