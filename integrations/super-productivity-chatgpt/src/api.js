import { readFile } from 'node:fs/promises';

export class ApiError extends Error {
  constructor(message, { uncertain = false } = {}) { super(message); this.uncertain = uncertain; }
}

export class SpApi {
  constructor(tokenFile, fetcher = fetch) { this.tokenFile = tokenFile; this.fetcher = fetcher; }
  async request(method, path, body) {
    // Fixed loopback destination. Never send this credential to a caller-supplied URL.
    const token = (await readFile(this.tokenFile, 'utf8')).trim();
    let response;
    try {
      response = await this.fetcher(`http://127.0.0.1:3876${path}`, {
        method, redirect: 'error', signal: AbortSignal.timeout(18000),
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
    } catch {
      throw new ApiError('Super Productivity is unavailable or the request timed out. Open the desktop app and enable its local REST API.', { uncertain: method !== 'GET' });
    }
    let result;
    try { result = await response.json(); } catch {
      throw new ApiError('Invalid response from Super Productivity.', { uncertain: method !== 'GET' });
    }
    if (!response.ok || !result.ok) {
      throw new ApiError(`Super Productivity rejected the request (${response.status}, ${result.error?.code || 'UNKNOWN'}).`, { uncertain: method !== 'GET' && response.status >= 500 });
    }
    return result.data;
  }
  projects() { return this.request('GET', '/projects'); }
  tags() { return this.request('GET', '/tags'); }
  tasks(filters = {}) {
    const params = new URLSearchParams();
    for (const [key, value] of Object.entries(filters)) if (value !== undefined) params.set(key, String(value));
    return this.request('GET', `/tasks?${params}`);
  }
  task(id) { return this.request('GET', `/tasks/${encodeURIComponent(id)}`); }
  create(fields) { return this.request('POST', '/tasks', fields); }
  update(id, fields) { return this.request('PATCH', `/tasks/${encodeURIComponent(id)}`, fields); }
}
