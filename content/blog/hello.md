---
title: "Hello from elm-pages"
description: "Our first blog post, demonstrating rich content components inside Markdown."
slug: hello
published: true
---

# Hello from elm-pages

Welcome to the blog. This post demonstrates how to use the component library inside Markdown content — including callouts, feature grids, and styled links.

<callout type="info">

This post is rendered by the `Route.Blog.Slug_` route, which loads Markdown from `content/blog/`. The same custom renderer used for regular pages handles all component tags here too.

</callout>

## What we built

The component library adds the following custom tags to Markdown:

<feature-grid columns="2">

<feature title="Callout" icon="📢">

Four variants — `info`, `success`, `warning`, `error` — for surfacing important information inline with content.

</feature>

<feature title="Hero" icon="🏠">

A full-width section with a headline, subtitle, and a CTA slot for `button-link` elements.

</feature>

<feature title="Feature Grid" icon="⊞">

A responsive 2–4 column grid of feature items, each with an optional icon, title, and description.

</feature>

<feature title="Pricing Table" icon="💳">

Side-by-side pricing tier cards with name, price, period, and a feature list.

</feature>

</feature-grid>

## Next steps

<callout type="success">

All components are standard Elm functions in `src/Components/`. You can import and call them directly from any route module — they don't have to be used through Markdown.

</callout>

Browse the [Component Showcase](/components) for a full reference with copy-paste examples of every tag.

<button-link href="/components" variant="primary">View all components</button-link>
