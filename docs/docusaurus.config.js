// @ts-check
// Note: type annotations allow type checking and IDEs autocompletion

const lightCodeTheme = {
  plain: {color: '#17263e', backgroundColor: '#ffffff'},
  styles: [
    {types: ['keyword', 'function', 'tag', 'number', 'boolean'], style: {color: '#245ac4'}},
    {types: ['string', 'attr-value'], style: {color: '#9b2452'}},
    {types: ['comment', 'prolog', 'doctype', 'cdata'], style: {color: '#4a5b73'}},
  ],
};
const darkCodeTheme = {
  plain: {color: '#ecf1fa', backgroundColor: '#18263b'},
  styles: [
    {types: ['keyword', 'function', 'tag', 'number', 'boolean'], style: {color: '#95bbff'}},
    {types: ['string', 'attr-value'], style: {color: '#f4b6d0'}},
    {types: ['comment', 'prolog', 'doctype', 'cdata'], style: {color: '#b6c4da'}},
  ],
};

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Dart Nostr',
  tagline: 'A Nostr SDK for Dart and Flutter',
  favicon: 'img/favicon.ico',

  url: process.env.SITE_URL || 'https://nostr.gwhyyy.com',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: process.env.BASE_URL || '/',
  trailingSlash: true,
  plugins: [require.resolve('./plugins/docs-search.cjs'), require.resolve('./plugins/analytics.cjs'), function discoveryFiles() {
    return {
      name: 'discovery-files',
      async postBuild({outDir, siteConfig}) {
        const fs = require('node:fs');
        const path = require('node:path');
        const root = `${siteConfig.url}${siteConfig.baseUrl}`;
        const summary = `# dart_nostr\n\n> An MIT-licensed Nostr SDK for Dart and Flutter. The published package is 11.2.0, which is what these guides and the playground use.\n\n## Documentation\n- [Overview](${root}docs/): SDK capabilities and API conventions.\n- [Installation](${root}docs/installation/): Install the published 11.2.0 release.\n- [Quick start](${root}docs/quick-start/): Connect, publish and subscribe.\n- [Errors](${root}docs/usage/advanced/error-handling/): Typed results and failures.\n- [Source](https://github.com/anasfik/nostr): Implementation and issue tracker.\n`;
        const files = fs.readdirSync(path.join(__dirname, 'docs'), {recursive: true}).filter(name => name.endsWith('.md')).sort();
        const full = files.map(name => `\n\n## Source: docs/${name}\n\n${fs.readFileSync(path.join(__dirname, 'docs', name), 'utf8')}`).join('');
        fs.writeFileSync(path.join(outDir, 'robots.txt'), `User-agent: *\nAllow: /\n\nSitemap: ${root}sitemap.xml\n`);
        fs.writeFileSync(path.join(outDir, 'llms.txt'), summary);
        fs.writeFileSync(path.join(outDir, 'llms-full.txt'), summary + full);
      },
    };
  }],

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: 'anasfik', // Usually your GitHub org/user name.
  projectName: 'nostr', // Usually your repo name.

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  // Even if you don't use internalization, you can use this field to set useful
  // metadata like html lang. For example, if your site is Chinese, you may want
  // to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          routeBasePath: 'docs',
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl:
            'https://github.com/anasfik/nostr/tree/main/docs/',
        },
        blog: false,
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      }),
    ],
  ],

  themeConfig:
    
    ({
      // Replace with your project's social card
      image: 'img/social-card.png',
      colorMode: {respectPrefersColorScheme: true},
      announcementBar: {
        id: 'release-112',
        backgroundColor: 'var(--surface)',
        textColor: 'var(--ink-2)',
        content: `dart_nostr 11.2.0 is published · <a href="${process.env.BASE_URL || '/'}docs/installation/">Install it</a>.`,
        isCloseable: false,
      },
      navbar: {
        title: 'Dart Nostr',
        logo: {
          alt: 'Dart Nostr logo',
          src: 'img/logo-nav.png',
          width: 40,
          height: 40,
        },
        items: [
          {to: '/search/', label: 'Search docs', position: 'right'},
          {href: 'https://pub.dev/packages/dart_nostr', label: 'pub.dev', position: 'right'},
          {
            type: 'docSidebar',
            sidebarId: 'tutorialSidebar',
            position: 'left',
            label: 'Documentation',
          },
          {
            href: 'https://github.com/anasfik/nostr',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'light',
        links: [
          {
            title: 'Docs',
            items: [
              {
                label: 'Documentation',
                to: '/docs/',
              },
            ],
          },
          {
            title: 'Community',
            items: [
              {
                label: 'Issues',
                href: 'https://github.com/anasfik/nostr/issues',
              },
              {
                label: 'Pub',
                href: 'https://pub.dev/packages/dart_nostr',
              },
            ],
          },
          {
            title: 'More',
            items: [

              {
                label: 'Author',
                href: 'https://github.com/anasfik',
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Anas Fikhi. Built with Docusaurus.`,
      },
      prism: {
        theme: lightCodeTheme,
        darkTheme: darkCodeTheme,
        additionalLanguages: ['dart']
      },
    }),
};

module.exports = config;
