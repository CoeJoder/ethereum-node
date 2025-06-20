import { defineConfig } from "astro/config";

import starlight from "@astrojs/starlight";

// https://astro.build/config
export default defineConfig({
  integrations: [starlight({
    title: "ethereum-node",
    favicon: '/favicon.ico',
    social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/CoeJoder/ethereum-node' }],
    sidebar: [
      {
        label: 'Guides',
        autogenerate: { directory: 'guides' },
      },
      {
        label: 'Reference',
        autogenerate: { directory: 'reference' },
      },
    ],
  })]
});
