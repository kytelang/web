import { defineConfig } from 'vitepress'
import kyteGrammar from './grammars/kyte.tmLanguage.json'

export default defineConfig({
  markdown: {
    // Load the real Kyte TextMate grammar (from the VSCode extension) so ```kyte and ```kyx
    // fences in the guide are syntax-highlighted instead of falling back to plain text.
    languages: [
      { ...(kyteGrammar as any), name: 'kyte', scopeName: 'source.ky', aliases: ['kyx'] },
    ],
  },
  title: 'Kyte',
  // GitHub Pages PROJECT page: served at https://kytelang.github.io/kyte-web/, so the base is the repo
  // name. The home component uses withBase(), so internal links follow automatically. To move to a custom
  // domain at root (e.g. kytelang.org), set this back to '/' and add public/CNAME.
  base: '/',
  description:
    'Kyte is a statically-typed language built for hypermedia web applications, with a single-threaded async runtime, self-hosted TLS, four database drivers, and a native orchestrator. One language, one toolchain, one binary.',
  cleanUrls: true,
  lastUpdated: true,
  // The guide links out to code paths (examples/, ../STABILITY.md) that do not exist in the site.
  ignoreDeadLinks: true,
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/kyte-logo.svg' }],
    ['link', { rel: 'icon', type: 'image/png', href: '/kyte-logo.png' }],
    ['meta', { name: 'theme-color', content: '#1f6feb' }],
    ['meta', { property: 'og:title', content: 'Kyte, a language for hypermedia services' }],
    ['meta', {
      property: 'og:description',
      content: 'A statically-typed language built for hypermedia web applications, with a single-threaded async runtime, self-hosted TLS, and a native orchestrator.'
    }],
  ],
  themeConfig: {
    logo: '/kyte-logo.svg',
    nav: [
      { text: 'Docs', link: '/guide/' },
    ],
    sidebar: {
      '/guide/': [
        {
          text: 'Overview',
          items: [{ text: 'The guide', link: '/guide/' }],
        },
        {
          text: 'Language',
          collapsed: false,
          items: [
            { text: '1. Getting started', link: '/guide/01-getting-started' },
            { text: '2. Values and types', link: '/guide/02-values-and-types' },
            { text: '3. Strings', link: '/guide/03-strings' },
            { text: '4. Control flow', link: '/guide/04-control-flow' },
            { text: '5. Functions and closures', link: '/guide/05-functions-and-closures' },
            { text: '6. Collections', link: '/guide/06-collections' },
            { text: '7. Structs', link: '/guide/07-structs' },
            { text: '8. Enums', link: '/guide/08-enums' },
            { text: '9. Traits', link: '/guide/09-traits' },
            { text: '10. Optionals', link: '/guide/10-optionals' },
            { text: '11. Error handling', link: '/guide/11-error-handling' },
            { text: '12. Decimal', link: '/guide/12-decimal' },
            { text: '13. Ownership', link: '/guide/13-ownership' },
            { text: '14. Modules', link: '/guide/14-modules' },
            { text: '15. Concurrency', link: '/guide/15-concurrency' },
            { text: '16. Serialization', link: '/guide/16-serialization' },
          ],
        },
        {
          text: 'Web and data',
          collapsed: false,
          items: [
            { text: '17. Web applications', link: '/guide/17-web' },
            { text: '18. Data access and the repository', link: '/guide/18-data-access' },
            { text: '19. Package management', link: '/guide/19-package-management' },
            { text: '20. Database drivers', link: '/guide/20-database-drivers' },
            { text: '21. Datastar hypermedia', link: '/guide/21-datastar' },
          ],
        },
        {
          text: 'Platform',
          collapsed: false,
          items: [
            { text: '22. Building and distributing', link: '/guide/22-building-and-distribution' },
            { text: '23. Deploying with Kynator', link: '/guide/23-deploying-with-the-orchestrator' },
            { text: '24. Artifact delivery', link: '/guide/24-blob-store' },
            { text: '25. Continuous deployment', link: '/guide/25-continuous-deployment' },
          ],
        },
        {
          text: 'kaidb database',
          collapsed: false,
          items: [
            { text: '26. kaidb overview', link: '/guide/26-kaidb-overview' },
            { text: '27. kaidb SQL reference', link: '/guide/27-kaidb-sql' },
            { text: '28. The kaidb CLI', link: '/guide/28-kaidb-cli' },
            { text: '29. Connecting from Kyte', link: '/guide/29-kaidb-driver' },
          ],
        },
        {
          text: 'Tools',
          collapsed: false,
          items: [
            { text: '30. Kyte Data Studio', link: '/guide/30-kyte-studio' },
          ],
        },
      ],
    },
    socialLinks: [{ icon: 'github', link: 'https://github.com/kytelang/kyte' }],
    search: { provider: 'local' },
    outline: { level: [2, 3] },
  },
})
