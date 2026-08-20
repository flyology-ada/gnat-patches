# Product

## Register

product

## Users

Ada and GNAT developers, GCC contributors, and reviewers use the site to
understand what a patchset changes in a compiler, read the evidence behind each
bundle, and decide whether a patched toolchain is worth installing. Upstream
maintainers use it to read one problem at a time: the offending C++, both Ada
outputs, the diff, and the executable regression.

## Product Purpose

The site is the readable face of the repository. It should make the current
patchset and its per-compiler effect obvious, let anyone browse a bundle's
explanation, patch, and tests without cloning, keep the distinction between a
patched compiler and a known-good control visible, and publish a JSON contract
that other tooling can consume. Nothing on it may claim more than the
manifests, checksums, and releases actually establish.

## Brand Personality

Precise, mechanical, and factual, in the register of a well-annotated compiler
changelog. Evidence first, no promotional claims, and no confidence the
repository has not earned.

## Anti-references

Avoid neon-terminal developer-tool cliches, generic card walls, marketing
language, adoption claims, and any presentation that makes a staged or
unpublished result look shipped.

## Design Principles

- Lead with the current patchset and what each compiler actually receives.
- Show a bundle's role per GCC major, because a bundle is patched on one
  release and an unpatched control on another.
- Keep the shortest path from a problem statement to its diff and its test.
- Distinguish a verified result from a CI expectation, a staged bundle from an
  accepted one, and a curated patchset from a published release.
- Derive every published representation from the repository, and fail the build
  rather than publish a claim it cannot support.
- Reuse the Flyology website kit's visual language and interaction patterns.

## Accessibility & Inclusion

Target WCAG 2.2 AA. Preserve semantic headings and disclosure controls, full
keyboard navigation, visible focus states, colour-independent meaning in every
matrix and diff, readable code at narrow widths, horizontal scrolling for wide
content instead of shrinking it, and a complete reduced-motion experience.
