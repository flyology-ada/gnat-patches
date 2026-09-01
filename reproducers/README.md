# Tool reproducers

This directory contains independently runnable failures in GNAT-adjacent tools
that are not GCC patch bundles. Each subdirectory pins the affected tool,
contains the smallest buildable fixture found, and provides a runner that
checks the observed failure signature.

These cases do not belong under `bundles/`: a bundle is a complete GCC source
patch with an executable before/after regression and release applicability
metadata.

| Reproducer | Affected tool | Failure |
| --- | --- | --- |
| [`gnatdoc-nested-generic-private`](gnatdoc-nested-generic-private/README.md) | GNATdoc 26.0.0 | A nested generic package in a parent's private part raises `GNATDOC.NOT_IMPLEMENTED` during public documentation generation. |
