import { defineConfig } from "astro/config";
import { rehypeTasklistEnhancer } from './config/plugins/rehype-tasklist-enhancer';

import starlight from "@astrojs/starlight";

// https://astro.build/config
export default defineConfig({
  site: 'https://CoeJoder.github.io',
  base: '/ethereum-node',
  integrations: [starlight({
    title: 'ethereum-node',
    logo: {
      src: './src/assets/ethnode-logo-trimmed.webp',
    },
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
    ]
  })],
  markdown: {
    rehypePlugins: [
      rehypeTasklistEnhancer(),
    ]
  }
});
