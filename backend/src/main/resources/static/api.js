export async function request(path, { method = 'GET', body } = {}) {
  let response;
  const uncertainWrite = 'The connection ended before save could be confirmed. This operation may have completed. Close this form and refresh or search the records before trying again.';
  try {
    const headers = body === undefined ? {} : { 'Content-Type': 'application/json' };
    // The local rollback-only demonstration is opt-in and refuses writes unless the server confirms test mode.
    if (new URLSearchParams(location.search).get('step5Rollback') === '1' && method !== 'GET' &&
        (/^\/rentals\/(start|\d+\/return)$/.test(path) || path === '/payments')) {
      const health = await fetch('/api/health', { signal: AbortSignal.timeout(8000) }).then(r => r.json());
      if (!health.testMode) throw new Error('Rollback demonstration requires the local test server.');
      headers['X-SVR-Rollback'] = 'true';
    }
    response = await fetch('/api' + path, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(8000)
    });
  } catch (error) {
    if (error.message === 'Rollback demonstration requires the local test server.') throw error;
    throw new Error(method === 'GET' ? 'Cannot reach the local server. Check that it is running, then retry.' : uncertainWrite);
  }
  let data;
  try { data = await response.json(); } catch { throw new Error(method === 'GET' ? 'The server returned an unreadable response.' : uncertainWrite); }
  if (!response.ok) throw new Error(data?.error?.message || `Request failed (${response.status}).`);
  if (response.headers.get('X-SVR-Rolled-Back') === 'true') data.rolledBack = true;
  return data;
}

export const query = (values) => {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(values)) if (value !== '' && value != null) params.set(key, value);
  const result = params.toString();
  return result ? '?' + result : '';
};
