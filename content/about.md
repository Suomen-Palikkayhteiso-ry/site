---
title: "About"
description: "About this site."
slug: about
published: true
---

# About

This site is built with [elm-pages](https://elm.dillonkearns.com) and a custom component library that extends Markdown with rich UI components.

<callout type="info">

**What is elm-pages?** It's a framework for building fast, type-safe static sites in Elm. Every page is pre-rendered at build time, so users get instant load times with no JavaScript required for content.

</callout>

## How it works

Content is written in standard Markdown. Custom HTML tags in the Markdown are intercepted by `dillonkearns/elm-markdown` and rendered as fully-styled Elm components.

<callout type="warning">

Custom component tags must be on their own lines with blank lines before and after, just like standard HTML blocks in Markdown. Inline use inside paragraphs is not supported.

</callout>

## Getting started

Browse the [Components](/components) page to see all available component tags and their usage examples.
