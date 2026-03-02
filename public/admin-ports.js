// SECURITY: Never log `token` or `window.__gh*` variables.
// Port implementations for the Admin route.

import { mountEditor, setContent, destroyEditor } from '../src/admin/Editor.js';

export function wireAdminPorts(app) {
  const STORAGE_KEY = 'gh_token';
  const DRAFT_PREFIX = 'draft:';
  let draftSaveTimer = null;

  // ── loadTokenFromStorage ────────────────────────────────────────────────────
  app.ports.loadTokenFromStorage.subscribe(() => {
    const token = localStorage.getItem(STORAGE_KEY);
    app.ports.tokenLoadedFromStorage.send(token);
  });

  // ── storeToken ─────────────────────────────────────────────────────────────
  app.ports.storeToken.subscribe((token) => {
    localStorage.setItem(STORAGE_KEY, token);
  });

  // ── clearToken ─────────────────────────────────────────────────────────────
  app.ports.clearToken.subscribe(() => {
    localStorage.removeItem(STORAGE_KEY);
  });

  // ── requestDeviceCode ──────────────────────────────────────────────────────
  app.ports.requestDeviceCode.subscribe(async ({ clientId, proxyUrl }) => {
    const base = proxyUrl || 'https://github.com';
    window.__githubOauthProxyUrl = base;
    window.__githubOauthClientId = clientId;
    try {
      const res = await fetch(`${base}/login/device/code`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json' },
        body: new URLSearchParams({ client_id: clientId, scope: window.__repoScope || 'public_repo' }),
      });
      const json = await res.json();
      if (json.error) throw new Error(json.error_description || json.error);
      app.ports.deviceCodeReceived.send({
        userCode: json.user_code,
        verificationUri: json.verification_uri,
        deviceCode: json.device_code,
        interval: json.interval ?? 5,
      });
    } catch (err) {
      console.error('requestDeviceCode error', err.message);
      app.ports.deviceCodeReceived.send({ error: err.message });
    }
  });

  // ── startPolling ───────────────────────────────────────────────────────────
  app.ports.startPolling.subscribe(async ({ deviceCode, interval }) => {
    const base = window.__githubOauthProxyUrl || 'https://github.com';
    const intervalMs = (interval ?? 5) * 1000;
    const timeout = Date.now() + 15 * 60 * 1000;

    const poll = async () => {
      if (Date.now() > timeout) {
        app.ports.tokenReceived.send({ error: 'Timed out' });
        return;
      }
      try {
        const res = await fetch(`${base}/login/oauth/access_token`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json' },
          body: new URLSearchParams({
            client_id: window.__githubOauthClientId,
            device_code: deviceCode,
            grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
          }),
        });
        const json = await res.json();
        if (json.access_token) {
          app.ports.tokenReceived.send({ token: json.access_token });
        } else if (json.error === 'authorization_pending') {
          setTimeout(poll, intervalMs);
        } else if (json.error === 'slow_down') {
          setTimeout(poll, intervalMs + 5000);
        } else {
          app.ports.tokenReceived.send({ error: json.error_description || json.error });
        }
      } catch (err) {
        app.ports.tokenReceived.send({ error: err.message });
      }
    };

    setTimeout(poll, intervalMs);
  });

  // ── listFiles ──────────────────────────────────────────────────────────────
  app.ports.listFiles.subscribe(async ({ token, owner, repo, path }) => {
    try {
      const res = await fetch(
        `https://api.github.com/repos/${owner}/${repo}/contents/${path}`,
        { headers: apiHeaders(token) }
      );
      if (!res.ok) throw new Error(`GitHub API ${res.status}`);
      const items = await res.json();
      const mdFiles = items
        .filter(i => i.type === 'file' && i.name.endsWith('.md'))
        .map(i => ({ path: i.path, name: i.name, sha: i.sha }));
      app.ports.filesListed.send(mdFiles);
    } catch (err) {
      console.error('listFiles error', err.message);
      app.ports.filesListed.send([]);
    }
  });

  // ── fetchFile ──────────────────────────────────────────────────────────────
  app.ports.fetchFile.subscribe(async ({ token, owner, repo, path }) => {
    window.__currentEditPath = path;
    try {
      const res = await fetch(
        `https://api.github.com/repos/${owner}/${repo}/contents/${path}`,
        { headers: apiHeaders(token) }
      );
      if (!res.ok) throw new Error(`GitHub API ${res.status}`);
      const item = await res.json();
      const content = atob(item.content.replace(/\n/g, ''));
      app.ports.fileLoaded.send({
        meta: { path: item.path, name: item.name, sha: item.sha },
        content,
      });
    } catch (err) {
      console.error('fetchFile error', err.message);
    }
  });

  // ── mountEditor ────────────────────────────────────────────────────────────
  app.ports.mountEditor.subscribe(() => {
    requestAnimationFrame(() => {
      mountEditor((newContent) => {
        app.ports.editorContentChanged.send(newContent);
      });
    });
  });

  // ── destroyEditor ──────────────────────────────────────────────────────────
  app.ports.destroyEditor.subscribe(() => {
    destroyEditor();
  });

  // ── setEditorContent ───────────────────────────────────────────────────────
  app.ports.setEditorContent.subscribe((content) => {
    setContent(content);
  });

  // ── editorContentChanged: auto-save draft with debounce ────────────────────
  app.ports.editorContentChanged.subscribe((content) => {
    clearTimeout(draftSaveTimer);
    draftSaveTimer = setTimeout(() => {
      const path = window.__currentEditPath;
      if (path) localStorage.setItem(DRAFT_PREFIX + path, content);
    }, 1000);
  });

  // ── saveDraft ──────────────────────────────────────────────────────────────
  app.ports.saveDraft.subscribe(({ path, content }) => {
    localStorage.setItem(DRAFT_PREFIX + path, content);
  });

  // ── loadDraft ──────────────────────────────────────────────────────────────
  app.ports.loadDraft.subscribe((path) => {
    const draft = localStorage.getItem(DRAFT_PREFIX + path);
    app.ports.draftLoaded.send(draft);
  });

  // ── clearDraft ─────────────────────────────────────────────────────────────
  app.ports.clearDraft.subscribe((path) => {
    localStorage.removeItem(DRAFT_PREFIX + path);
    window.__currentEditPath = null;
  });

  // ── commitFile ─────────────────────────────────────────────────────────────
  app.ports.commitFile.subscribe(async ({ token, owner, repo, path, content, sha, message }) => {
    try {
      const encoded = btoa(unescape(encodeURIComponent(content)));
      const res = await fetch(
        `https://api.github.com/repos/${owner}/${repo}/contents/${path}`,
        {
          method: 'PUT',
          headers: apiHeaders(token, { 'Content-Type': 'application/json' }),
          body: JSON.stringify({ message, content: encoded, sha }),
        }
      );
      const json = await res.json();
      if (!res.ok) {
        throw new Error(json.message || `GitHub API ${res.status}`);
      }
      app.ports.commitDone.send({ sha: json.commit.sha });
    } catch (err) {
      console.debug('commitFile: error', err.message);
      app.ports.commitDone.send({ error: err.message });
    }
  });

  // ── startBuildPolling ──────────────────────────────────────────────────────
  app.ports.startBuildPolling.subscribe(async ({
    commitSha, token, owner, repo, pageUrl,
    actionsIntervalMs, pageIntervalMs, timeoutMs,
  }) => {
    const deadline = Date.now() + timeoutMs;

    const emit = (event, extra = {}) =>
      app.ports.buildStatusUpdate.send({ event, ...extra });

    const pollActions = async () => {
      while (Date.now() < deadline) {
        try {
          const res = await fetch(
            `https://api.github.com/repos/${owner}/${repo}/actions/runs`
            + `?head_sha=${commitSha}&event=push&per_page=1`,
            { headers: apiHeaders(token) }
          );
          const json = await res.json();
          const run = json.workflow_runs?.[0];

          if (!run) {
            emit('actionsQueued');
          } else if (run.status === 'queued') {
            emit('actionsQueued');
          } else if (run.status === 'in_progress') {
            emit('actionsRunning');
          } else if (run.status === 'completed') {
            if (run.conclusion === 'success') {
              emit('actionsComplete');
              return true;
            } else {
              emit('actionsFailed', { reason: run.conclusion ?? 'unknown' });
              return false;
            }
          }
        } catch (err) {
          console.warn('Actions poll error', err.message);
        }
        await sleep(actionsIntervalMs);
      }
      emit('timedOut');
      return false;
    };

    const pollPage = async () => {
      const configUrl = `https://${owner}.github.io/${repo}/site-config.json`;
      while (Date.now() < deadline) {
        try {
          const res = await fetch(configUrl, { cache: 'no-store' });
          const json = await res.json();
          if (json.buildSha === commitSha) {
            emit('pageMatched', { pageUrl });
            return;
          }
        } catch (err) {
          console.warn('Page poll error', err.message);
        }
        await sleep(pageIntervalMs);
      }
      emit('timedOut');
    };

    const actionsOk = await pollActions();
    if (actionsOk) await pollPage();
  });
}

function apiHeaders(token, extra = {}) {
  return {
    Authorization: `Bearer ${token}`,
    Accept: 'application/vnd.github+json',
    ...extra,
  };
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
