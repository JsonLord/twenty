---
title: Twenty
emoji: 💼
colorFrom: blue
colorTo: indigo
sdk: docker
app_port: 7860
---

<p align="center">
  <a href="https://www.twenty.com">
    <img src="./packages/twenty-website/public/images/core/logo.svg" width="100px" alt="Twenty logo" />
  </a>
</p>

<h2 align="center">The #1 Open-Source CRM</h2>

<p align="center"><a href="https://twenty.com"><img src="./packages/twenty-website/public/images/readme/globe-icon.svg" width="12" height="12"/> Website</a> · <a href="https://docs.twenty.com"><img src="./packages/twenty-website/public/images/readme/book-icon.svg" width="12" height="12"/> Documentation</a> · <a href="https://github.com/orgs/twentyhq/projects/1"><img src="./packages/twenty-website/public/images/readme/map-icon.svg" width="12" height="12"/> Roadmap </a> · <a href="https://discord.gg/cx5n4Jzs57"><img src="./packages/twenty-website/public/images/readme/discord-icon.svg" width="12" height="12"/> Discord</a> · <a href="https://www.figma.com/file/xt8O9mFeLl46C5InWwoMrN/Twenty"><img src="./packages/twenty-website/public/images/readme/figma-icon.webp"  width="12" height="12"/>  Figma</a></p>

<p align="center">
  <a href="https://www.twenty.com">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="./packages/twenty-website/public/images/readme/github-cover-dark.webp" />
      <source media="(prefers-color-scheme: light)" srcset="./packages/twenty-website/public/images/readme/github-cover-light.webp" />
      <img src="./packages/twenty-website/public/images/readme/github-cover-light.webp" alt="Twenty banner" />
    </picture>
  </a>
</p>

<br />

# Why Twenty

Twenty gives technical teams the building blocks for a custom CRM that meets complex business needs and quickly adapts as the business evolves. Twenty is the CRM you build, ship, and version like the rest of your stack.

<a href="https://twenty.com/resources/why-twenty"><img src="./packages/twenty-website/public/images/readme/star-icon.svg" width="14" height="14"/> Learn more about why we built Twenty</a>

<br />

# Installation

### <img src="./packages/twenty-website/public/images/readme/globe-icon.svg" width="14" height="14"/> Cloud

The fastest way to get started. Sign up at [twenty.com](https://twenty.com) and spin up a workspace in under a minute, with no infrastructure to manage and always up to date.

### <img src="./packages/twenty-website/public/images/readme/book-icon.svg" width="14" height="14"/> Build an app

Scaffold a new app with the Twenty CLI:

```bash
npx create-twenty-app my-app
```

Define objects, fields, and views as code:

```ts
import { defineObject, FieldType } from 'twenty-sdk/define';

export default defineObject({
  nameSingular: 'deal',
  namePlural: 'deals',
  labelSingular: 'Deal',
  labelPlural: 'Deals',
  fields: [
    { name: 'name', label: 'Name', type: FieldType.TEXT },
    { name: 'amount', label: 'Amount', type: FieldType.CURRENCY },
    { name: 'closeDate', label: 'Close Date', type: FieldType.DATE_TIME },
  ],
});
```

Then ship it to your workspace:

```bash
npx twenty app:publish --private
```

See the [app development guide](https://docs.twenty.com/developers/extend/apps/getting-started) for objects, views, agents, and logic functions.

### <img src="./packages/twenty-website/public/images/readme/rocket-icon.svg" width="14" height="14"/> Self-hosting

Run Twenty on your own infrastructure with [Docker Compose](https://docs.twenty.com/developers/self-host/capabilities/docker-compose), or contribute locally via the [local setup guide](https://docs.twenty.com/developers/contribute/capabilities/local-setup).

#### Hugging Face Space Deployment

This repository's default Docker target is a self-contained, single-container
Hugging Face deployment. It runs the Twenty web server on port `7860`, the
Twenty queue worker, PostgreSQL, and Redis. PostgreSQL and Redis bind only to
`127.0.0.1`; they are not exposed by the image. Uploaded files use Twenty's
supported local filesystem driver. Docker Compose, Docker-in-Docker, external
databases, S3, and external queue services are not required.

The startup supervisor initializes and upgrades the database, waits for
PostgreSQL and Redis, starts the web server and waits for `/healthz`, and only
then starts the worker and registers recurring jobs. Any essential process
exiting stops the container.

##### Persistence

All mutable state has one root, `TWENTY_DATA_DIR` (default `/data/twenty`):

```text
/data/twenty/
├── postgres/  # durable CRM database
├── storage/   # uploaded files
├── logs/
├── runtime/   # sockets and non-durable Redis data
└── secrets/   # generated app, encryption, and database secrets
```

Attach Hugging Face persistent storage at `/data` to retain this hierarchy. A
Space without persistent storage still boots, but **its database, uploads, and
generated secrets can disappear after a restart, rebuild, or reallocation**.
Alternatively, mount persistent storage elsewhere and set `TWENTY_DATA_DIR` to
a directory on that mount before first boot.

##### Configuration and required secrets

No external service variables are required. The image sets local
`PG_DATABASE_URL`, `REDIS_URL`, `STORAGE_TYPE=local`, ports, and the public Space
URL. It generates cryptographically random `APP_SECRET`, `ENCRYPTION_KEY`, and
an internal PostgreSQL password on first boot and stores them under
`$TWENTY_DATA_DIR/secrets` with restricted permissions. You may instead set
`APP_SECRET` and `ENCRYPTION_KEY` as persistent Hugging Face Secrets; never use
new values with an existing database unless intentionally rotating keys.

| Variable | Type | Description |
|---|---|---|
| `APP_SECRET` | Secret (optional) | Persistent session-signing secret; generated locally when omitted |
| `ENCRYPTION_KEY` | Secret (optional) | Persistent at-rest encryption key; generated locally when omitted |
| `SERVER_URL` | Variable (optional) | Public deployment URL; defaults to `https://leon4gr45-twenty.hf.space` |
| `TWENTY_DATA_DIR` | Variable (optional) | Common persistent root; defaults to `/data/twenty` |
| `TWENTY_LIGHT_MODE` | Variable (optional) | Set `true` to omit the separate worker and cron registration |

Do not override `PG_DATABASE_URL` or `REDIS_URL`: this image intentionally
requires its bundled localhost services.

##### PostgreSQL and Redis choices

Twenty requires PostgreSQL-specific TypeORM data sources and has no supported
SQLite adapter. The image uses PostgreSQL 18, matching the version already used
by this checkout's all-in-one target, with 20 connections, 48 MiB shared
buffers, one autovacuum worker, and parallel query execution disabled. It binds
only to `127.0.0.1` and a socket beneath the data root.

Twenty uses BullMQ 5 for job queues and Redis for cache/client services. The
upstream deployment and CI in this checkout validate Redis, not Valkey, so the
Space retains the small Alpine Redis package rather than claiming unverified
BullMQ compatibility. Persistence is disabled because PostgreSQL is the durable
CRM store; `noeviction` avoids corrupting BullMQ semantics. No unsafe small
`maxmemory` cap is imposed.

##### Light mode

The server and worker are separate upstream entry points, so basic synchronous
CRM UI/API reads and writes can run with `TWENTY_LIGHT_MODE=true`. Redis remains
required by server cache, session, and queue providers. Light mode does not run
the worker or register recurring jobs: queued workflows, email/calendar sync,
webhook delivery, imports/exports, search indexing, and other asynchronous or
scheduled work will remain queued. Full mode is the safe default.

##### Memory footprint

Run `runtime-memory` inside the container for a lightweight per-component RSS
table. Exact RSS depends on dataset and traffic. A real idle measurement is not
recorded here because this development environment does not provide a Docker
daemon; do not treat estimates as measurements. The PostgreSQL configuration
reserves 48 MiB shared buffers and Redis allocates on demand without persistence.

The Docker build also uses a single shared dependency-resolution stage. The
server and frontend builds are deliberately serialized because Hugging Face's
BuildKit otherwise executes both memory-heavy branches concurrently. Yarn fetch
concurrency is limited to eight requests, Nx remains single-worker, and Node
heaps are capped at 1536 MiB for dependencies/server and 2048 MiB for the
frontend.

##### Troubleshooting

```bash
# Public readiness and frontend
curl -fsS http://127.0.0.1:7860/healthz
curl -fsS http://127.0.0.1:7860/ >/dev/null

# Local-only dependencies
pg_isready -h 127.0.0.1 -p 5432 -U twenty
redis-cli -h 127.0.0.1 ping

# Processes, memory, disk, and logs
ps -ef | grep -E 'postgres|redis-server|dist/main|queue-worker'
runtime-memory
df -h "${TWENTY_DATA_DIR:-/data/twenty}"
du -sh "${TWENTY_DATA_DIR:-/data/twenty}"/*
```

Startup diagnostics go to the Space runtime log without printing credentials.
If the worker is absent, confirm `TWENTY_LIGHT_MODE` is not `true`. Database or
queue readiness failures usually indicate exhausted disk/memory or damaged
ephemeral state; preserve the logs before replacing the affected data directory.

<br />
<br />

# Everything you need

Twenty gives you the building blocks of a modern CRM (objects, views, workflows, and agents) and lets you extend them as code. Here's a tour of what's in the box.

Want to go deeper? Read the <a href="https://docs.twenty.com/user-guide/introduction"><img src="./packages/twenty-website/public/images/readme/planner-icon.svg" width="14" height="14"/> User Guide</a> for product walkthroughs, or the <a href="https://docs.twenty.com"><img src="./packages/twenty-website/public/images/readme/book-icon.svg" width="14" height="14"/> Documentation</a> for developer reference.

<table align="center">
  <tr>
    <td width="50%">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="./packages/twenty-website/public/images/readme/v2-build-apps-dark.webp" />
        <source media="(prefers-color-scheme: light)" srcset="./packages/twenty-website/public/images/readme/v2-build-apps-light.webp" />
        <img src="./packages/twenty-website/public/images/readme/v2-build-apps-light.webp" alt="Create your apps" />
      </picture>
      <p align="center"><a href="https://docs.twenty.com/developers/extend/apps/getting-started"><img src="./packages/twenty-website/public/images/readme/code-icon.svg" width="16" height="16"/> Learn more about apps in doc</a></p>
    </td>
    <td width="50%">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="./packages/twenty-website/public/images/readme/v2-version-control-dark.webp" />
        <source media="(prefers-color-scheme: light)" srcset="./packages/twenty-website/public/images/readme/v2-version-control-light.webp" />
        <img src="./packages/twenty-website/public/images/readme/v2-version-control-light.webp" alt="Stay on top with version control" />
      </picture>
      <p align="center"><a href="https://docs.twenty.com/developers/extend/apps/publishing"><img src="./packages/twenty-website/public/images/readme/monitor-icon.svg" width="16" height="16"/> Learn more about version control in doc</a></p>
    </td>
  </tr>
  <tr>
    <td width="50%">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="./packages/twenty-website/public/images/readme/v2-all-tools-dark.webp" />
        <source media="(prefers-color-scheme: light)" srcset="./packages/twenty-website/public/images/readme/v2-all-tools-light.webp" />
        <img src="./packages/twenty-website/public/images/readme/v2-all-tools-light.webp" alt="All the tools you need to build anything" />
      </picture>
      <p align="center"><a href="https://docs.twenty.com/developers/extend/apps/building"><img src="./packages/twenty-website/public/images/readme/rocket-icon.svg" width="16" height="16"/> Learn more about primitives in doc</a></p>
    </td>
    <td width="50%">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="./packages/twenty-website/public/images/readme/v2-tools-dark.webp" />
        <source media="(prefers-color-scheme: light)" srcset="./packages/twenty-website/public/images/readme/v2-tools-light.webp" />
        <img src="./packages/twenty-website/public/images/readme/v2-tools-light.webp" alt="Customize your layouts" />
      </picture>
      <p align="center"><a href="https://docs.twenty.com/user-guide/layout/overview"><img src="./packages/twenty-website/public/images/readme/planner-icon.svg" width="16" height="16"/> Learn more about layouts in doc</a></p>
    </td>
  </tr>
  <tr>
    <td width="50%">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="./packages/twenty-website/public/images/readme/v2-ai-agents-dark.webp" />
        <source media="(prefers-color-scheme: light)" srcset="./packages/twenty-website/public/images/readme/v2-ai-agents-light.webp" />
        <img src="./packages/twenty-website/public/images/readme/v2-ai-agents-light.webp" alt="AI agents and chats" />
      </picture>
      <p align="center"><a href="https://docs.twenty.com/user-guide/ai/overview"><img src="./packages/twenty-website/public/images/readme/message-icon.svg" width="16" height="16"/> Learn more about AI in doc</a></p>
    </td>
    <td width="50%">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="./packages/twenty-website/public/images/readme/v2-crm-tools-dark.webp" />
        <source media="(prefers-color-scheme: light)" srcset="./packages/twenty-website/public/images/readme/v2-crm-tools-light.webp" />
        <img src="./packages/twenty-website/public/images/readme/v2-crm-tools-light.webp" alt="Plus all the tools of a good CRM" />
      </picture>
      <p align="center"><a href="https://docs.twenty.com/user-guide/introduction"><img src="./packages/twenty-website/public/images/readme/star-icon.svg" width="16" height="16"/> Learn more about CRM features in doc</a></p>
    </td>
  </tr>
</table>

<br />

# Stack

- <a href="https://www.typescriptlang.org/"><img src="./packages/twenty-website/public/images/readme/stack-typescript.svg" width="14" height="14"/> TypeScript</a>
- <a href="https://nx.dev/"><img src="./packages/twenty-website/public/images/readme/stack-nx.svg" width="14" height="14"/> Nx</a>
- <a href="https://nestjs.com/"><img src="./packages/twenty-website/public/images/readme/stack-nestjs.svg" width="14" height="14"/> NestJS</a>, with <a href="https://bullmq.io/">BullMQ</a>, <a href="https://www.postgresql.org/"><img src="./packages/twenty-website/public/images/readme/stack-postgresql.svg" width="14" height="14"/> PostgreSQL</a>, <a href="https://redis.io/"><img src="./packages/twenty-website/public/images/readme/stack-redis.svg" width="14" height="14"/> Redis</a>
- <a href="https://reactjs.org/"><img src="./packages/twenty-website/public/images/readme/stack-react.svg" width="14" height="14"/> React</a>, with <a href="https://jotai.org/">Jotai</a>, <a href="https://linaria.dev/">Linaria</a> and <a href="https://lingui.dev/">Lingui</a>

# Thanks

<p align="center">
  <a href="https://greptile.com"><img src="./packages/twenty-website/public/images/readme/greptile.webp" height="28" alt="Greptile" /></a>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://sentry.io/"><img src="./packages/twenty-website/public/images/readme/sentry.webp" height="28" alt="Sentry" /></a>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://crowdin.com/"><img src="./packages/twenty-website/public/images/readme/crowdin.webp" height="28" alt="Crowdin" /></a>
</p>

Thanks to these amazing services that we use and recommend for code review (Greptile), catching bugs (Sentry) and translating (Crowdin).

# Join the Community

<p><a href="https://github.com/twentyhq/twenty"><img src="./packages/twenty-website/public/images/readme/star-icon.svg" width="12" height="12"/> Star the repo</a> · <a href="https://discord.gg/cx5n4Jzs57"><img src="./packages/twenty-website/public/images/readme/discord-icon.svg" width="12" height="12"/> Discord</a> · <a href="https://github.com/twentyhq/twenty/discussions"><img src="./packages/twenty-website/public/images/readme/message-icon.svg" width="12" height="12"/> Feature requests</a> · <a href="https://github.com/orgs/twentyhq/projects/1/views/35"><img src="./packages/twenty-website/public/images/readme/rocket-icon.svg" width="12" height="12"/> Releases</a> · <a href="https://twitter.com/twentycrm"><img src="./packages/twenty-website/public/images/readme/x-icon.svg" width="12" height="12"/> X</a> · <a href="https://www.linkedin.com/company/twenty/"><img src="./packages/twenty-website/public/images/readme/linkedin-icon.svg" width="12" height="12"/> LinkedIn</a> · <a href="https://twenty.crowdin.com/twenty"><img src="./packages/twenty-website/public/images/readme/language-icon.svg" width="12" height="12"/> Crowdin</a> · <a href="https://github.com/twentyhq/twenty/contribute"><img src="./packages/twenty-website/public/images/readme/code-icon.svg" width="12" height="12"/> Contribute</a></p>
