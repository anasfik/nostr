// @ts-check

const {themes} = require('prism-react-renderer');
const lightCodeTheme = themes.github;
const darkCodeTheme = themes.dracula;

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Dart Nostr',
  tagline: 'A Dart and Flutter SDK for the Nostr protocol',
  favicon: 'img/favicon.ico',

  url: 'https://anasfik.github.io',
  baseUrl: '/nostr/',

  organizationName: 'anasfik',
  projectName: 'nostr',

  onBrokenLinks: 'throw',
  onBrokenAnchors: 'throw',

  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'throw',
      onBrokenMarkdownImages: 'throw',
    },
  },

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
          routeBasePath: '/',
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl: 'https://github.com/anasfik/nostr/edit/main/docs/',
          showLastUpdateAuthor: false,
          showLastUpdateTime: false,
        },
        blog: false,
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
        sitemap: {
          filename: 'sitemap.xml',
          lastmod: 'date',
          changefreq: 'weekly',
          priority: 0.5,
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/logo.png',
      metadata: [
        {
          name: 'description',
          content:
            'Documentation for dart_nostr, a Dart and Flutter SDK for the Nostr protocol: keys, events, relays, subscriptions, and NIP utilities.',
        },
        {
          name: 'keywords',
          content: 'nostr, dart, flutter, sdk, relays, events, nips',
        },
      ],
      colorMode: {
        defaultMode: 'light',
        disableSwitch: false,
        respectPrefersColorScheme: true,
      },
      navbar: {
        title: 'Dart Nostr',
        logo: {
          alt: 'Dart Nostr logo',
          src: 'img/logo.png',
          width: 32,
          height: 32,
        },
        items: [
          {
            to: '/',
            label: 'Getting started',
            position: 'left',
          },
          {
            to: '/reference/nip-coverage',
            label: 'Protocols',
            position: 'left',
          },
          {
            to: '/reference/accessors',
            label: 'API',
            position: 'left',
          },
          {
            href: 'https://github.com/anasfik/nostr',
            label: 'GitHub',
            position: 'right',
          },
          {
            href: 'https://pub.dev/packages/dart_nostr',
            label: 'Pub',
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
              {label: 'Getting started', to: '/'},
              {label: 'Installation', to: '/installation'},
              {label: 'Quick start', to: '/quick-start'},
            ],
          },
          {
            title: 'Reference',
            items: [
              {label: 'Protocol coverage', to: '/reference/nip-coverage'},
              {label: 'API accessors', to: '/reference/accessors'},
            ],
          },
          {
            title: 'Community',
            items: [
              {
                label: 'GitHub issues',
                href: 'https://github.com/anasfik/nostr/issues',
              },
              {
                label: 'Pub package',
                href: 'https://pub.dev/packages/dart_nostr',
              },
              {label: 'Author', href: 'https://github.com/anasfik'},
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Anas Fikhi. Built with Docusaurus.`,
      },
      prism: {
        theme: lightCodeTheme,
        darkTheme: darkCodeTheme,
        additionalLanguages: ['dart'],
      },
      tableOfContents: {
        minHeadingLevel: 2,
        maxHeadingLevel: 3,
      },
    }),
};

module.exports = config;
