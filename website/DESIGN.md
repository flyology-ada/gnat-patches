---
name: GNAT Patch Catalog
description: A browsable, machine-readable catalog of GCC/GNAT patch bundles and the patchsets that ship them.
colors:
  ink: "oklch(27% 0.052 270)"
  ink-soft: "oklch(39% 0.043 270)"
  violet: "oklch(57% 0.19 285)"
  violet-deep: "oklch(47% 0.18 285)"
  teal: "oklch(73% 0.13 185)"
  teal-deep: "oklch(56% 0.11 185)"
  paper: "oklch(98.5% 0.006 270)"
  surface: "oklch(95.8% 0.015 270)"
  surface-strong: "oklch(92.5% 0.024 270)"
  line: "oklch(86% 0.025 270)"
  code-bg: "oklch(23% 0.045 270)"
typography:
  body:
    fontFamily: "Geologica, Avenir Next, Segoe UI, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.65
  mono:
    fontFamily: "ui-monospace, SFMono-Regular, Cascadia Code, Roboto Mono, monospace"
    fontSize: "0.82rem"
    fontWeight: 400
    lineHeight: 1.7
rounded:
  control: "0.45rem"
  panel: "0.9rem"
  feature: "1.4rem"
spacing:
  xs: "0.45rem"
  sm: "0.85rem"
  md: "1.25rem"
  lg: "2rem"
---

# Design System: GNAT Patch Catalog

## Overview

The catalog is a product-oriented extension of the Flyology website kit. It
inherits the kit's Geologica typography, tinted technical grid, violet and teal
semantic palette, light and dark themes, focus treatment, and code surface.
Its own content is denser than a landing page and more structural than a
crate index: compiler diffs, per-release role matrices, and manifest metadata.

## Information hierarchy

Five routes carry the site. The home page states the current patchset and the
role every accepted bundle plays on every supported GCC major. `/patchsets/`
lists releases newest first; a patchset page pins one GCC source release per
major, carries its publication state, and links each bundle it applies,
controls, or stages. `/bundles/` lists every bundle, and a bundle page is the
deep view: role matrix, rendered explanation, per-variant diffs, test sources,
commands, and complete manifest metadata. `/unreleased/` is the staged set with
its dependency structure. `/panels/` carries the coverage panels.

Earlier patchsets are browsable but diminished: they keep their compilers,
release facts, and membership, and they carry a banner saying the bundle detail
shown is each bundle's current manifest rather than its state at the time.

## Components

- The role matrix is the site's central component. A cell states its role in
  words — patched, known-good control, staged, not applicable — and adds an
  inset rule and a tonal wash. Violet marks a patched compiler, teal a
  known-good control, and neutral a staged or absent one. The wording carries
  the meaning; colour only reinforces it.
- Diffs are rendered as tables, one per touched file, with original and patched
  line numbers, hunk headers, and per-line highlighting in the language of the
  target file. Number and marker cells are not selectable, so copying a diff
  copies source. Wide hunks scroll inside their own container.
- Code is highlighted at build time into the kit's `token-*` classes, so no page
  ships a highlighting script and every sample renders identically without
  JavaScript.
- Metadata is a definition grid rather than a table, so a long provenance
  sentence and a checksum can sit beside each other and wrap independently.
- Long panel prose sits inside a native disclosure, closed by default, so the
  feature matrix is what the page opens with.
- Pills state status, application order, and release state. A dashed border
  marks anything provisional: staged, superseded, unpublished, unchecked.

## Responsive and accessible behavior

Matrices, diffs, and metadata collapse to a single reading column on narrow
viewports. Long paths, hashes, and hunks scroll horizontally rather than
shrinking. Native `details` and `summary` elements retain keyboard and
assistive-technology behaviour, diff rows label added and removed lines for
screen readers, and every table carries a caption and header scopes. Motion is
limited to transforms and opacity and is removed when reduced motion is
requested.
