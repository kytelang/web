<script setup lang="ts">
import { withBase } from 'vitepress'
import { ref, computed, onMounted } from 'vue'

// OS-detecting install block. The one-liner points at install.sh / install.ps1 served
// from this site's own public/ folder, so it stays correct wherever the site is deployed.
const osTabs = [
  { id: 'macos', label: 'macOS', note: 'Apple Silicon' },
  { id: 'linux', label: 'Linux', note: 'x86_64 · arm64' },
  { id: 'windows', label: 'Windows', note: 'x86_64' },
]
const activeOs = ref('macos')
const copied = ref(false)
const shUrl = ref('https://kytelang.org/install.sh')
const psUrl = ref('https://kytelang.org/install.ps1')

const command = computed(() =>
  activeOs.value === 'windows'
    ? `powershell -c "irm ${psUrl.value} | iex"`
    : `curl -fsSL ${shUrl.value} | sh`
)
const installDir = computed(() => (activeOs.value === 'windows' ? '%USERPROFILE%\\.kyte' : '~/.kyte'))
const binDir = computed(() => (activeOs.value === 'windows' ? '.kyte\\bin' : '~/.kyte/bin'))

onMounted(() => {
  if (typeof window === 'undefined') return
  shUrl.value = window.location.origin + withBase('/install.sh')
  psUrl.value = window.location.origin + withBase('/install.ps1')
  const nav: any = navigator
  const p = `${nav.userAgentData?.platform || ''} ${nav.platform || ''} ${nav.userAgent || ''}`
  if (/Win/i.test(p)) activeOs.value = 'windows'
  else if (/Mac|iPhone|iPad|iPod/i.test(p)) activeOs.value = 'macos'
  else if (/Linux|X11|Android/i.test(p)) activeOs.value = 'linux'
})

async function copyCommand() {
  try {
    await navigator.clipboard.writeText(command.value)
    copied.value = true
    setTimeout(() => (copied.value = false), 1600)
  } catch {
    // Clipboard blocked (insecure context); the command stays selectable by hand.
  }
}
// The landing is a "stack ledger": Kyte shown as the sequence of layers it unifies, each row noting
// what it replaces. The numbering is real (source -> running system), not decoration.
const layers = [
  { n: '01', name: 'Language', detail: 'Statically typed, ES6 syntax, compiled to native via LLVM.', repl: 'no runtime surprises', tone: 'azure' },
  { n: '02', name: 'Async runtime', detail: 'A single-threaded async reactor with deterministic ARC memory.', repl: 'no GC pauses', tone: 'azure' },
  { n: '03', name: 'Crypto and TLS', detail: 'TLS 1.3 and all crypto, self-hosted, hardware AES and SHA.', repl: 'no OpenSSL', tone: 'green' },
  { n: '04', name: 'Web framework', detail: 'Vertical slices, typed handlers, hypermedia by default.', repl: 'no framework sprawl', tone: 'green' },
  { n: '05', name: 'Data access', detail: 'One Connection interface, four drivers, compile-checked row binding and a generic repository.', repl: 'no ORM lock-in', tone: 'orange' },
  { n: '06', name: 'Kynator', detail: 'Replicas, load balancing, and an HA config store, deployed from a release.', repl: 'instead of k8s', tone: 'ink' },
]

const pillars = [
  {
    tone: 'azure', tag: 'The language',
    title: 'Familiar syntax, native output',
    body: 'ES6 and TypeScript flavoured, statically typed, compiled straight to a native binary. async and await, traits, exact decimals, and deterministic reference counting instead of a garbage collector.',
    link: '/guide/01-getting-started', cta: 'Start the guide',
  },
  {
    tone: 'green', tag: 'Data access',
    title: 'One interface, four databases',
    body: 'A single Connection interface with compile-checked row binding and a generic repository, so changing stores does not rewrite your data layer. Kyte drives PostgreSQL, MySQL, SQL Server, and MongoDB through the same interface, each added as a package and reached by one connection string.',
    link: '/guide/18-data-access', cta: 'Data access',
  },
  {
    tone: 'orange', tag: 'Kynator',
    title: 'Deploy without the platform',
    body: 'Kynator, the Kyte-native orchestrator, runs replicas behind a load balancer, kept at their desired count, with an HA config store. Zero-downtime rollouts, a leader lease, and content-addressed delivery of the exact binary you built. Install it on a Linux host straight from a GitHub release.',
    link: '/guide/23-deploying-with-the-orchestrator', cta: 'Deploying',
  },
]

const chips = [
  'Statically typed', 'ES6 syntax', 'Single-threaded reactor', 'ARC, no GC',
  'Self-hosted TLS 1.3', 'Hardware AES / SHA',
  'Hypermedia web', 'Four DB drivers', 'Compile-time SQL checks',
  'Zero-downtime deploys', 'Cross-compiles Linux / Windows / macOS',
  'Language server (LSP)', 'VS Code extension', 'In-editor debugger', 'Package manager',
]
</script>

<template>
  <div class="nv">
    <!-- Masthead: a compact spec header, not a hero. -->
    <header class="nv-mast">
      <div class="nv-mast-line">
        <span class="nv-kicker">kyte // a language for hypermedia services</span>
        <span class="nv-kicker nv-kicker-dim">beta 0.1.0</span>
      </div>
      <h1 class="nv-word">Kyte</h1>
      <p class="nv-lede">
        A statically-typed language built for <em>hypermedia</em> web applications, where the server
        renders HTML the browser swaps in. Your whole service compiles to one native binary: the runtime,
        web framework, TLS, and database drivers all come from a single toolchain. It pairs with Kynator,
        a native orchestrator to run it in production.
      </p>
      <div class="nv-mast-links">
        <a class="nv-link nv-link-azure" :href="withBase('/guide/')">Read the guide →</a>
        <a class="nv-link" :href="withBase('/guide/17-web')">Build a web app</a>
        <a class="nv-link" href="https://github.com/kytelang/kyte">GitHub</a>
      </div>
    </header>

    <!-- Install: OS-detecting one-liner. -->
    <section class="nv-dl" aria-label="Download and install">
      <div class="nv-dl-aside">
        <span class="nv-eyebrow">Install</span>
        <p class="nv-dl-note">
          One command fetches the toolchain built for your machine and unpacks it into a
          <code>.kyte</code> folder in your home directory: the <code>kyte</code> compiler, the language
          server, and the standard library. No package manager, no system dependencies.
        </p>
        <div class="nv-badge-one">macOS · Linux · Windows</div>
      </div>
      <div class="nv-dl-panel">
        <div class="nv-dl-tabs" role="tablist" aria-label="Operating system">
          <button
            v-for="t in osTabs"
            :key="t.id"
            class="nv-dl-tab"
            :class="{ 'is-active': activeOs === t.id }"
            role="tab"
            :aria-selected="activeOs === t.id"
            @click="activeOs = t.id"
          >
            <span class="nv-dl-tab-label">{{ t.label }}</span>
            <span class="nv-dl-tab-note">{{ t.note }}</span>
          </button>
        </div>
        <div class="nv-dl-cmd">
          <code class="nv-dl-code">{{ command }}</code>
          <button class="nv-dl-copy" type="button" @click="copyCommand">{{ copied ? 'Copied' : 'Copy' }}</button>
        </div>
        <p class="nv-dl-sub">
          Installs to <code>{{ installDir }}</code>, then add <code>{{ binDir }}</code> to your PATH.
          <a class="nv-link nv-link-azure" href="https://github.com/kytelang/kyte/releases/latest">Manual downloads and checksums →</a>
        </p>
        <p class="nv-dl-sub">
          Deploying a service? Kynator, the orchestrator, installs onto a Linux host from its own release.
          <a class="nv-link nv-link-azure" :href="withBase('/guide/23-deploying-with-the-orchestrator')">Deploy with Kynator →</a>
        </p>
      </div>
    </section>

    <!-- The signature: the stack ledger. -->
    <section class="nv-stack" aria-label="What Kyte unifies">
      <div class="nv-stack-aside">
        <span class="nv-eyebrow">The stack, collapsed</span>
        <p class="nv-stack-note">
          The first five layers compile into your one binary, written in Kyte itself, so a service does
          not stitch them together from separate projects. Kynator is a companion service, built for the
          same stack, that you deploy alongside it.
        </p>
        <div class="nv-badge-one">one language · one toolchain · one binary</div>
      </div>
      <ol class="nv-ledger">
        <li v-for="(l, i) in layers" :key="l.n" class="nv-row" :class="'t-' + l.tone" :style="{ '--i': i }">
          <span class="nv-row-n">{{ l.n }}</span>
          <span class="nv-row-body">
            <span class="nv-row-name">{{ l.name }}</span>
            <span class="nv-row-detail">{{ l.detail }}</span>
          </span>
          <span class="nv-row-repl">{{ l.repl }}</span>
        </li>
      </ol>
    </section>

    <!-- Three pillars. -->
    <section class="nv-pillars" aria-label="Three pillars">
      <article v-for="p in pillars" :key="p.tag" class="nv-pillar" :class="'t-' + p.tone">
        <span class="nv-pillar-tag">{{ p.tag }}</span>
        <h2 class="nv-pillar-title">{{ p.title }}</h2>
        <p class="nv-pillar-body">{{ p.body }}</p>
        <a class="nv-pillar-link" :href="withBase(p.link)">{{ p.cta }} →</a>
      </article>
    </section>

    <!-- A real slice of code. -->
    <section class="nv-code" aria-label="A web slice">
      <div class="nv-code-side">
        <span class="nv-eyebrow">One slice, end to end</span>
        <p class="nv-code-note">
          A web feature in Kyte is a small folder: an input type, a handler, a view. The handler reads
          typed input with <code>ctx.bind</code> and runs its query through a repository over the
          <code>Connection</code> interface. No mediator, no dependency-injection container. This is the whole
          thing.
        </p>
        <a class="nv-link nv-link-azure" :href="withBase('/guide/17-web')">See the full walkthrough →</a>
      </div>
      <pre class="nv-pre"><code><span class="c">// GET /api/products/{id:int}</span>
<span class="k">pub struct</span> <span class="t">GetProductByIdHandler</span> <span class="k">impl</span> <span class="t">RouteHandler</span> {
    repo: <span class="t">ProductRepository</span>,

    <span class="k">async fn</span> <span class="f">serve</span>(self, ctx: <span class="t">Context</span>): <span class="t">Response</span> {
        <span class="k">let</span> q = ctx.<span class="f">bind</span>&lt;<span class="t">GetProductById</span>&gt;();
        <span class="k">let</span> found = <span class="k">await</span> self.repo.<span class="f">findById</span>(q.id);
        <span class="k">if</span> (found == <span class="k">undefined</span>) {
            <span class="k">return</span> response.<span class="f">Response</span>(<span class="t">Status</span>.NotFound, <span class="s">"not found"</span>);
        }
        <span class="k">return</span> response.<span class="f">Response</span>(<span class="t">Status</span>.Ok, <span class="f">productCard</span>(found));
    }
}</code></pre>
    </section>

    <!-- Capability chips. -->
    <section class="nv-chips-wrap" aria-label="What is inside">
      <span class="nv-eyebrow">What is inside</span>
      <ul class="nv-chips">
        <li v-for="c in chips" :key="c" class="nv-chip">{{ c }}</li>
      </ul>
    </section>

    <!-- Reading band. -->
    <section class="nv-read" aria-label="Start reading">
      <div class="nv-read-head">
        <h2 class="nv-read-title">Start reading</h2>
        <p class="nv-read-sub">Twenty-four chapters, from your first program to a deployed, load-balanced service.</p>
      </div>
      <div class="nv-read-cols">
        <div class="nv-read-col">
          <span class="nv-read-k">Language</span>
          <a :href="withBase('/guide/01-getting-started')">Getting started</a>
          <a :href="withBase('/guide/07-structs')">Structs and classes</a>
          <a :href="withBase('/guide/11-error-handling')">Error handling</a>
          <a :href="withBase('/guide/15-concurrency')">Concurrency</a>
        </div>
        <div class="nv-read-col">
          <span class="nv-read-k">Web and data</span>
          <a :href="withBase('/guide/17-web')">Web applications</a>
          <a :href="withBase('/guide/18-data-access')">Data access and the repository</a>
          <a :href="withBase('/guide/19-package-management')">Package management</a>
          <a :href="withBase('/guide/20-database-drivers')">Database drivers</a>
        </div>
        <div class="nv-read-col">
          <span class="nv-read-k">Platform</span>
          <a :href="withBase('/guide/22-building-and-distribution')">Building and distributing</a>
          <a :href="withBase('/guide/23-deploying-with-the-orchestrator')">Deploying with Kynator</a>
          <a :href="withBase('/guide/24-blob-store')">Artifact delivery</a>
        </div>
      </div>
    </section>
  </div>
</template>
