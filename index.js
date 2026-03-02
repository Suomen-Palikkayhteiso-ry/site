import { wireAdminPorts } from './public/admin-ports.js';

const config = {
    load: async function (elmLoaded) {
        const app = await elmLoaded;
        wireAdminPorts(app);

        // Expose site config values for the polling closure
        fetch('/site-config.json')
            .then(r => r.json())
            .then(cfg => {
                window.__githubOauthClientId = cfg.oauthClientId;
                window.__githubOauthProxyUrl = cfg.oauthProxyUrl;
                window.__repoScope = cfg.repoScope || 'public_repo';
            })
            .catch(() => {});
    },
    flags: function () {
        return null;
    },
};
export default config;
