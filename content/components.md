---
title: "Component Showcase"
description: "All available component tags for use in Markdown content."
slug: components
published: true
---

# Component Showcase

Every component registered in `MarkdownRenderer.elm` is demonstrated below. Use these HTML tags inside any Markdown file to render rich UI components.

---

## Callout / Alert

Use `<callout type="…">` for attention-grabbing notices. The `type` attribute accepts `info`, `success`, `warning`, or `error`.

<callout type="info">

This is an **info** callout. Use it for helpful background information or tips.

</callout>

<callout type="success">

This is a **success** callout. Use it to confirm that something worked as expected.

</callout>

<callout type="warning">

This is a **warning** callout. Use it to highlight something the reader should be careful about.

</callout>

<callout type="error">

This is an **error** callout. Use it to call out a known problem or breaking change.

</callout>

---

## Hero Section

Use `<hero title="…" subtitle="…">` to render a large centred hero. Place `<button-link>` tags inside as the call-to-action slot.

<hero title="Your headline goes here" subtitle="A supporting sentence that gives the reader more context about what this page or product is about.">

<button-link href="#" variant="primary">Get Started</button-link>
<button-link href="#" variant="secondary">Learn More</button-link>

</hero>

---

## Button Link

Use `<button-link href="…" variant="…">` to render a styled anchor. The `variant` attribute accepts `primary`, `secondary`, or `ghost` (default is `primary`).

<button-link href="#" variant="primary">Primary</button-link>
<button-link href="#" variant="secondary">Secondary</button-link>
<button-link href="#" variant="ghost">Ghost</button-link>

---

## Feature Grid

Use `<feature-grid columns="2|3">` to wrap `<feature>` items in a responsive grid. The optional `columns` attribute accepts `2`, `3`, or `4` (default is `3`).

<feature-grid columns="3">

<feature title="Fast builds" icon="⚡">

elm-pages pre-renders every page at build time. No server-side work at request time.

</feature>

<feature title="Type safety" icon="✓">

Elm's compiler catches mistakes before they reach production. Refactor with confidence.

</feature>

<feature title="SEO ready" icon="◎">

Every page ships with configurable meta tags and structured data out of the box.

</feature>

<feature title="Markdown-first" icon="✎">

Author content in plain Markdown and drop in components where you need them.

</feature>

<feature title="Tailwind CSS" icon="✦">

Style everything with utility classes. No custom CSS files to maintain.

</feature>

<feature title="Git-based CMS" icon="⎇">

Content lives alongside your code. Commit, review, and deploy with standard git workflows.

</feature>

</feature-grid>

---

## Pricing Table

Use `<pricing-table>` to wrap `<pricing-tier>` cards in a grid. Each tier has required `name` and `price` attributes and an optional `period`.

<pricing-table>

<pricing-tier name="Free" price="$0" period="month">

- 1 site
- 10 pages
- Community support
- Git deploy

</pricing-tier>

<pricing-tier name="Pro" price="$12" period="month">

- Unlimited sites
- Unlimited pages
- Priority support
- Custom domain
- Analytics

</pricing-tier>

<pricing-tier name="Team" price="$49" period="month">

- Everything in Pro
- 5 team members
- SSO / SAML
- SLA guarantee
- Dedicated support

</pricing-tier>

</pricing-table>

---

## Card

Use `<card title="…">` to wrap content in a bordered card. The `title` attribute is optional and renders a header.

<card title="Getting Started">

Everything you need to launch your first elm-pages site in under five minutes. Clone the starter, run `make dev`, and start writing Markdown.

</card>

<card>

A card without a title is just a clean content container — useful for callouts, tips, or any isolated block of text.

</card>

---

## Badge

Use `<badge color="…">` inline to label content. The `color` attribute accepts `gray`, `blue`, `green`, `yellow`, `red`, `purple`, or `indigo`.

<badge color="indigo">New</badge> <badge color="green">Stable</badge> <badge color="yellow">Beta</badge> <badge color="red">Deprecated</badge> <badge color="gray">Draft</badge>

---

## Accordion

Use `<accordion>` to wrap `<accordion-item summary="…">` elements. Each item uses the native `<details>` element — no JavaScript required.

<accordion>

<accordion-item summary="What is elm-pages?">

elm-pages is a framework for building statically generated sites and web apps with Elm. It handles routing, data fetching, and SEO so you can focus on your content and UI.

</accordion-item>

<accordion-item summary="Do I need to know Elm to use this site?">

Not to read it! But if you want to add new component types or modify the layout, a basic understanding of Elm will help. The component library is designed to be extended incrementally.

</accordion-item>

<accordion-item summary="How do I add a new page?">

Create a new Markdown file in the `content/` directory with a frontmatter block (`title`, `description`, `slug`, `published`). elm-pages picks it up automatically on the next build.

</accordion-item>

<accordion-item summary="Can I use custom components in Markdown?">

Yes — that's exactly what this page demonstrates. Components are registered in `src/MarkdownRenderer.elm` as custom HTML tags, then used directly in any `.md` file.

</accordion-item>

</accordion>

---

## Stat Grid

Use `<stat-grid>` to wrap `<stat>` items. Each stat requires `label` and `value` attributes; `change` is optional and shown in green.

<stat-grid>

<stat label="Total Pages Published" value="24" change="+3 this month"></stat>

<stat label="Avg. Build Time" value="8.4s"></stat>

<stat label="Lighthouse Score" value="100" change="↑ 2pts"></stat>

<stat label="Components Available" value="12" change="+6 new"></stat>

</stat-grid>

---

## Timeline

Use `<timeline>` to wrap `<timeline-item date="…" title="…">` elements. Ideal for changelogs, roadmaps, or project histories.

<timeline>

<timeline-item date="March 2026" title="Component library complete">

Added Accordion, Stat Grid, Timeline, Card, and Badge components. All components are usable directly from Markdown via custom HTML tags.

</timeline-item>

<timeline-item date="February 2026" title="Tailwind CSS v4 + Admin polish">

Migrated to Tailwind v4 with the Vite plugin. Fixed the commit button bug and redesigned the admin layout with utility classes.

</timeline-item>

<timeline-item date="January 2026" title="In-browser authoring launched">

Shipped the full 10-phase implementation: GitHub OAuth, CodeMirror editor, draft auto-save, one-click commit, and build-status detection.

</timeline-item>

<timeline-item date="December 2025" title="Project kickoff">

Initial elm-pages site scaffolded with Cloudflare Pages deployment, custom routing for blog and content slugs, and a basic Markdown renderer.

</timeline-item>

</timeline>
