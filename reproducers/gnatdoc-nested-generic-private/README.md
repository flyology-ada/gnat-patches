# GNATdoc nested generic package in a private part

GNATdoc 26.0.0 raises `GNATDOC.NOT_IMPLEMENTED` while generating public HTML
documentation for a valid package specification containing a nested generic
package in the parent's private part. The internal error names
`GenericPackageDecl` at `gnatdoc-frontend.adb:909`.

The fixture is deliberately smaller than the Flyology CRC source where the
failure was first observed. It has one library package, one private part, and
one empty nested generic package. Removing the nested generic declaration and
leaving an ordinary private object makes the same GNATdoc command complete.

## Reproduce

Install [Alire](https://alire.ada.dev/), select a native toolchain, and run:

```sh
./run.sh
```

The runner uses Alire to install `gnatdoc_bin=26.0.0` into the ignored local
`.alire-prefix/` directory and builds the Ada project with the same Alire
environment. It invokes GNATdoc with these fixed arguments; the runner adds
isolated temporary object and output directories:

```sh
alr exec -- .alire-prefix/bin/gnatdoc \
  --backend html --warnings --style leading --generate public \
  -P reproducer.gpr
```

GNATdoc currently reports the internal error but exits with status 0. The
runner therefore checks the exception, source location, and node kind rather
than treating the process status as the regression result.

Expected diagnostic excerpt:

```text
p.ads:3:4: internal error:
p.ads:3:4: raised GNATDOC.NOT_IMPLEMENTED : at gnatdoc-frontend.adb:909 <GenericPackageDecl ["G"] p.ads:3:4-5:10>
```

A leading `@exclude` comment immediately before the nested generic declaration
was also tested. GNATdoc still traversed the declaration and raised the same
exception, so the tag is not part of this minimal fixture and is not a
workaround.

## Verified environment

- Host: macOS 26.6.2 (`arm64`)
- Alire: 2.1.1
- Alire releases: `gnatdoc_bin=26.0.0`, `gnat_native=16.1.0`, and
  `gprbuild=26.0.1`
- Executables: `GNATdoc 26.0.0 (20260415)`, `GNATMAKE 16.1.0`, and
  `GPRBUILD 26.0.0 (2026-04-15) (aarch64-apple-darwin24.6.0)`

Other compiler and host combinations have not been measured by this
reproducer.
