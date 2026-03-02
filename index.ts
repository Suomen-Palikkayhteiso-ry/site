import { wireAdminPorts } from './public/admin-ports.js';

type ElmPagesInit = {
  load: (elmLoaded: Promise<unknown>) => Promise<void>;
  flags: unknown;
};

const config: ElmPagesInit = {
  load: async function (elmLoaded) {
    const app = await elmLoaded;
    wireAdminPorts(app);

    // Expose site config values for the polling closure
    fetch('/site-config.json')
      .then(r => r.json())
      .then((cfg: { oauthClientId: string; oauthProxyUrl: string; repoScope?: string }) => {
        (window as any).__githubOauthClientId = cfg.oauthClientId;
        (window as any).__githubOauthProxyUrl = cfg.oauthProxyUrl;
        (window as any).__repoScope = cfg.repoScope || 'public_repo';
      })
      .catch(() => {});
  },
  flags: function () {
    return null;
  },
};

export default config;
