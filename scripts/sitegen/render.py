"""Render the catalog as the published pages.

Every page is written from the loaded catalog, so nothing on the site can
describe evidence the manifests do not carry. Prose comes from the bundle and
panel READMEs, patches are rendered as structured diffs, and metadata is
emitted field by field: a manifest key this module does not name explicitly is
still published rather than silently dropped.
"""

from __future__ import annotations

import html
from pathlib import PurePosixPath
from typing import Any, Iterable

from . import diffs, highlight, markdown, model

CANONICAL_URL = model.CANONICAL_URL
REPOSITORY_URL = model.REPOSITORY_URL

NAV = (
    ("patchsets/", "Patchsets", "patchsets"),
    ("bundles/", "Bundles", "bundles"),
    ("unreleased/", "Unreleased", "unreleased"),
    ("panels/", "Panels", "panels"),
    ("patches.json", "JSON", "json"),
)

STATUS_LABEL = {"accepted": "Accepted", "staged": "Staged"}

RELEASE_STATE_LABEL = {
    "published": "Published",
    "prerelease": "Release candidate",
}

BUNDLE_FIELDS: tuple[tuple[str, str], ...] = (
    ("affected_versions", "Affected releases"),
    ("known_good_versions", "Known-good releases"),
    ("files_modified", "Files modified"),
    ("regression_tests", "Regression tests"),
    ("expected_failure_before_patch", "Before the patch"),
    ("expected_success_after_patch", "After the patch"),
    ("upstream_issue", "Upstream issue"),
    ("upstream_submission_state", "Upstream submission"),
    ("source_provenance", "Provenance"),
    ("licensing", "Licensing"),
    ("repository_fixture", "Repository fixture"),
    ("fixture_sha256", "Fixture SHA-256"),
    ("repository_test_runner", "Test runner"),
)

COMMAND_FIELDS: tuple[tuple[str, str], ...] = (
    ("application_command", "Apply the patch"),
    ("build_command", "Build the compiler"),
    ("test_command", "Run the regression"),
)

#  Keys rendered by dedicated sections or by the page header.
HANDLED_KEYS = frozenset(
    {
        "schema",
        "id",
        "status",
        "standalone_patch",
        "introduced_in_patchset",
        "staged_in_patchset",
        "staged_reason",
        "staged_depends_on",
        "problem",
        "variants",
        "title",
        "readme_path",
        "directory",
        "tests",
        "roles",
    }
    | {key for key, _ in BUNDLE_FIELDS}
    | {key for key, _ in COMMAND_FIELDS}
)

FEATURE_STATE_KIND = {
    "verified": ("verified-working", "verified-working-with-guard", "verified-ada-compile",
                 "verified-runtime", "verified-runtime-interoperability",
                 "verified-with-target-boundary"),
    "patched": ("patched", "patched-with-method-wrapper-boundary"),
    "staged": ("staged", "staged-with-access-view"),
    "limited": ("facade-required", "not-emitted"),
}


def escape(value: Any) -> str:
    return html.escape(str(value), quote=False)


def attribute(value: Any) -> str:
    return html.escape(str(value), quote=True)


def prefix_for(depth: int) -> str:
    return "../" * depth


def bundle_href(prefix: str, identifier: str) -> str:
    return f"{prefix}bundles/{identifier}/"


def patchset_href(prefix: str, version: str) -> str:
    return f"{prefix}patchsets/{version}/"


def panel_href(prefix: str, identifier: str) -> str:
    return f"{prefix}panels/{identifier}/"


def repository_href(path: str) -> str:
    return f"{REPOSITORY_URL}/blob/main/{path}"


def code(value: Any) -> str:
    return f"<code>{escape(value)}</code>"


def code_list(values: Iterable[Any]) -> str:
    items = [f"<li>{code(value)}</li>" for value in values]
    return f'<ul class="code-list">{"".join(items)}</ul>' if items else "<p>None.</p>"


def code_block(language: str, source: str, *, label: str = "") -> str:
    rendered = highlight.highlight(language, source.rstrip("\n"))
    heading = f'<div class="code-label">{escape(label)}</div>' if label else ""
    return f'<div class="code-panel">{heading}<pre><code>{rendered}</code></pre></div>'


LANGUAGE_LABEL = {"ada": "Ada", "cpp": "C++", "shell": "shell", "text": "text"}


def source_fold(path: str, source: str, *, actions: str = "") -> str:
    """Return one source file as a fold, closed until a reader asks for it."""
    name = PurePosixPath(path).name
    language = highlight.language_for_path(path)
    lines = source.rstrip("\n").count("\n") + 1
    return f"""
        <details class="fold fold-source">
          <summary>
            <span class="fold-name"><code>{escape(name)}</code></span>
            <span class="fold-meta">{escape(LANGUAGE_LABEL.get(language, language))} &middot; {lines} lines</span>
          </summary>
          <div class="fold-body">
            {code_block(language, source)}
            {actions}
          </div>
        </details>"""


def markdown_html(
    source: str, *, source_path: str, prefix: str, embedded: bool = False
) -> str:
    """Return SOURCE as HTML.

    SOURCE_PATH is the document's repository path, which is what relative links
    inside it are resolved against. An embedded document sits under a page
    section that already carries its title, so its own first heading is dropped
    and the rest are demoted to keep a single heading outline on the page.
    """
    if embedded:
        source = markdown.strip_first_heading(source)
    return markdown.render(
        source,
        highlight=lambda info, body: highlight.highlight(
            highlight.language_for_info(info), body
        ),
        heading_offset=1 if embedded else 0,
        link_resolver=link_resolver(source_path, prefix),
    )


def link_resolver(source_path: str, prefix: str):
    """Return a resolver mapping a document's links onto published pages.

    Repository READMEs link to each other by relative path. A link that lands
    on a bundle or on the panel becomes a link to that page; anything else in
    the repository becomes a link to the file on GitHub.
    """
    base = PurePosixPath(source_path).parent

    def resolve(destination: str) -> str:
        if destination.startswith(("http://", "https://", "mailto:", "#", "/")):
            return destination
        target, _, fragment = destination.partition("#")
        if not target:
            return destination
        suffix = f"#{fragment}" if fragment else ""
        path = normalize(base / target)
        parts = path.split("/")

        if parts[0] == "bundles" and len(parts) >= 2:
            if parts[1] == "README.md":
                return f"{prefix}bundles/{suffix}"
            if len(parts) == 2 or (len(parts) == 3 and parts[2] == "README.md"):
                return f"{prefix}bundles/{parts[1]}/{suffix}"
        if parts[0] == "panels" and len(parts) >= 2:
            if len(parts) == 2 or (len(parts) == 3 and parts[2] == "README.md"):
                return f"{prefix}panels/{parts[1]}/{suffix}"
        return repository_href(path) + suffix

    return resolve


def normalize(path: PurePosixPath) -> str:
    parts: list[str] = []
    for part in path.parts:
        if part == ".":
            continue
        if part == "..":
            if parts:
                parts.pop()
            continue
        parts.append(part)
    return "/".join(parts)


def pill(kind: str, text: str) -> str:
    return f'<span class="pill pill-{attribute(kind)}">{escape(text)}</span>'


def definition(term: str, description: str) -> str:
    return f"<div><dt>{escape(term)}</dt><dd>{description}</dd></div>"


def field_value(value: Any) -> str:
    if isinstance(value, bool):
        return "Yes" if value else "No"
    if isinstance(value, list):
        return code_list(value)
    text = str(value)
    if _looks_like_path(text) or _looks_like_digest(text):
        return code(text)
    return escape(text)


def _looks_like_path(value: str) -> bool:
    return "/" in value and " " not in value


def _looks_like_digest(value: str) -> bool:
    return len(value) == 64 and all(character in "0123456789abcdef" for character in value)


def page(
    *,
    title: str,
    description: str,
    depth: int,
    canonical: str,
    body: str,
    current: str = "",
) -> str:
    prefix = prefix_for(depth)
    links = []
    for target, label, key in NAV:
        marker = ' aria-current="page"' if key == current else ""
        download = " download" if target.endswith(".json") else ""
        links.append(f'<li><a href="{attribute(prefix + target)}"{marker}{download}>{escape(label)}</a></li>')
    links.append(f'<li><a href="{REPOSITORY_URL}">GitHub</a></li>')

    return f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="{attribute(description)}">
    <meta name="theme-color" content="#17213d">
    <title>{escape(title)}</title>
    <link rel="canonical" href="{attribute(CANONICAL_URL + canonical)}">
    <link rel="icon" href="{attribute(prefix)}flyology-logo.svg" type="image/svg+xml">
    <link rel="stylesheet" href="{attribute(prefix)}assets/styles/site.css">
    <link rel="stylesheet" href="{attribute(prefix)}assets/styles/patches.css">
    <script src="{attribute(prefix)}assets/scripts/site.js"></script>
  </head>
  <body>
    <a class="skip-link" href="#main">Skip to content</a>
    <header class="site-header">
      <nav class="site-nav" aria-label="Primary navigation">
        <a class="brand" href="{attribute(prefix or './')}" aria-label="GNAT patches home">
          <img class="brand-mark" src="{attribute(prefix)}flyology-mark.svg" alt="">
          <span>GNAT patches</span>
        </a>
        <ul class="nav-links" data-nav-links>{"".join(links)}</ul>
        <div class="nav-tools">
          <button class="icon-button" type="button" data-theme-toggle>
            <span class="visually-hidden" data-theme-label>Use dark theme</span>
            <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M12 3v2m0 14v2M3 12h2m14 0h2M5.6 5.6 7 7m10 10 1.4 1.4M18.4 5.6 17 7M7 17l-1.4 1.4"/><circle cx="12" cy="12" r="4"/></svg>
          </button>
          <button class="menu-button" type="button" data-menu-toggle aria-expanded="false">
            <span class="visually-hidden">Toggle navigation</span>
            <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M4 7h16M4 12h16M4 17h16"/></svg>
          </button>
        </div>
      </nav>
    </header>
{body}
    <footer class="site-footer">
      <div class="footer-inner">
        <p>Generated from the <a href="{REPOSITORY_URL}">gnat-patches</a> manifests. Compiler patches remain GPL-3.0-or-later.</p>
        <div class="footer-links"><a href="{attribute(prefix)}patches.json">Catalog JSON</a><a href="{attribute(prefix)}llms.txt">llms.txt</a></div>
      </div>
    </footer>
  </body>
</html>
"""


def breadcrumbs(prefix: str, trail: list[tuple[str, str]], current: str) -> str:
    parts = []
    for target, label in trail:
        parts.append(f'<a href="{attribute(prefix + target)}">{escape(label)}</a>')
        parts.append('<span aria-hidden="true">/</span>')
    parts.append(f'<span aria-current="page">{escape(current)}</span>')
    return f'<nav class="breadcrumbs" aria-label="Breadcrumb">{"".join(parts)}</nav>'


#  Role matrix.


def role_matrix(
    patchset: dict[str, Any],
    bundles: list[dict[str, Any]],
    prefix: str,
    *,
    caption: str,
) -> str:
    majors = [target["gcc_major"] for target in patchset["targets"]]
    head = "".join(
        f'<th scope="col">GCC {escape(major)}<span>{escape(target["source_version"])}</span></th>'
        for major, target in zip(majors, patchset["targets"])
    )

    rows = []
    for bundle in bundles:
        cells = []
        entries = bundle["roles"][patchset["version"]]
        for major in majors:
            entry = entries[str(major)]
            role = entry["role"]
            variant = entry["variant"]
            detail = f'<span class="role-variant">{escape(variant)}</span>' if variant else ""
            cells.append(
                f'<td class="role-cell role-{attribute(role)}">'
                f'<span class="role-label">{escape(model.ROLE_LABEL[role])}</span>{detail}</td>'
            )
        rows.append(
            f'<tr><th scope="row"><a href="{attribute(bundle_href(prefix, bundle["id"]))}">'
            f'{escape(bundle["title"])}</a><span class="role-id"><code>{escape(bundle["id"])}</code></span></th>'
            f'{"".join(cells)}</tr>'
        )

    return f"""
        <div class="table-scroll">
          <table class="role-table">
            <caption>{escape(caption)}</caption>
            <thead><tr><th scope="col">Bundle</th>{head}</tr></thead>
            <tbody>{"".join(rows)}</tbody>
          </table>
        </div>
        <dl class="role-legend">
          {"".join(
              f"<div><dt>{escape(model.ROLE_LABEL[role])}</dt><dd>{escape(model.ROLE_DESCRIPTION[role])}</dd></div>"
              for role in (model.PATCHED, model.CONTROL, model.STAGED, model.ABSENT)
          )}
        </dl>"""


#  Release and installation.


def release_panel(target: dict[str, Any], *, checked: bool) -> str:
    release = target.get("release")
    if not checked:
        return (
            '<div class="release-state release-unknown"><p><strong>Publication state not checked.</strong> '
            "This site was generated without querying the release API.</p></div>"
        )
    if release is None:
        return (
            '<div class="release-state release-none"><p><strong>Not published.</strong> '
            "No toolchain release carries this patchset for this compiler. The bundles below are "
            "validated in the repository, but there is no compiler to install yet.</p></div>"
        )

    state = release["state"]
    label = RELEASE_STATE_LABEL.get(state, state)
    platforms = (
        "<p>Toolchains: " + ", ".join(escape(name) for name in release["platforms"]) + ".</p>"
        if release["platforms"]
        else "<p>This release carries no native toolchain archive.</p>"
    )
    install = ""
    if state == "published":
        install = code_block(
            "shell",
            f"alr -n toolchain --select --local \\\n"
            f"  {release['alire_crate']}={release['alire_version']}",
            label="Select this compiler",
        )

    return f"""
          <div class="release-state release-{attribute(state)}">
            <p><strong>{escape(label)}.</strong> <a href="{attribute(release['url'])}">{escape(release['name'])}</a>
            &middot; tag <code>{escape(release['tag'])}</code></p>
            {platforms}
          </div>
          {install}"""


def index_panel(patchset: dict[str, Any], *, checked: bool) -> str:
    """Return the one-time Alire index command, when anything is installable."""
    installable = checked and any(
        (target.get("release") or {}).get("state") == "published"
        for target in patchset["targets"]
    )
    if not installable:
        return ""
    command = (
        f"alr index --add \\\n"
        f"  {model.ALIRE_INDEX_URL} \\\n"
        f"  --name flyology --before community"
    )
    return f"""
      <section class="section" aria-labelledby="install-title">
        <h2 id="install-title" class="section-title">Install.</h2>
        <p class="section-lede">Add the Flyology index once, then select a compiler below from an Alire workspace.</p>
        {code_block("shell", command, label="Add the index")}
      </section>"""


#  Home.


def render_home(catalog: dict[str, Any], panels: list[dict[str, Any]]) -> str:
    patchset = catalog["patchsets"][0]
    accepted = [bundle for bundle in catalog["bundles"] if bundle["status"] == "accepted"]
    staged = [bundle for bundle in catalog["bundles"] if bundle["status"] == "staged"]
    published = catalog["latest_published_patchset"]

    if not catalog["publication_checked"]:
        standing = (
            '<p class="hero-note">Publication state was not checked when this site was built.</p>'
        )
    elif published == patchset["version"]:
        standing = '<p class="hero-note">This patchset is published as a toolchain release.</p>'
    elif published:
        standing = (
            f'<p class="hero-note">This patchset is not published yet. The newest installable '
            f'toolchain is <a href="{attribute(patchset_href("", published))}">patchset {escape(published)}</a>.</p>'
        )
    else:
        standing = '<p class="hero-note">No patchset is published as a toolchain release yet.</p>'

    body = f"""
    <main id="main">
      <section class="patch-hero page-shell" aria-labelledby="page-title">
        <div>
          <p class="eyebrow">GCC and GNAT patch bundles</p>
          <h1 id="page-title">Patchset {escape(patchset['version'])}.</h1>
          <p class="hero-lede">Independent GCC patch bundles, each with an executable regression, validated against pinned GCC source releases. Every page here is generated from the repository's manifests.</p>
          {standing}
          <div class="actions">
            <a class="button button-primary" href="{attribute(patchset_href('', patchset['version']))}">Open patchset {escape(patchset['version'])}</a>
            <a class="button button-secondary" href="bundles/">Browse {len(accepted)} bundles</a>
          </div>
        </div>
      </section>
      <div class="status-strip">
        <div class="status-inner page-shell">
          <p class="status-item"><strong>{len(accepted)}</strong> accepted bundles</p>
          <p class="status-item"><strong>{len(staged)}</strong> staged bundles</p>
          <p class="status-item"><strong>{len(catalog['patchsets'])}</strong> patchsets</p>
          <p class="status-item"><strong>{len(catalog['sources'])}</strong> pinned GCC releases</p>
        </div>
      </div>
      <section class="section page-shell" aria-labelledby="matrix-title">
        <div class="section-heading">
          <div>
            <p class="eyebrow">Patchset {escape(patchset['version'])}</p>
            <h2 id="matrix-title">What each compiler receives.</h2>
          </div>
          <p>A bundle is not the same on every GCC major. Where a release does not have the defect, its patch is not applied and the bundle's regression runs against the unpatched compiler as a control.</p>
        </div>
        {role_matrix(patchset, accepted, "", caption=f"Bundle roles in patchset {patchset['version']}")}
      </section>
      {render_staged_teaser(staged)}
      {render_panel_teaser(panels)}
    </main>"""

    return page(
        title="GNAT patches",
        description="GCC and GNAT patch bundles with executable regressions, validated against pinned GCC source releases.",
        depth=0,
        canonical="",
        body=body,
    )


def render_staged_teaser(staged: list[dict[str, Any]]) -> str:
    if not staged:
        return ""
    items = "".join(
        f'<li><a href="{attribute(bundle_href("", bundle["id"]))}">{escape(bundle["title"])}</a>'
        f'<span>{escape(bundle.get("staged_reason", ""))}</span></li>'
        for bundle in staged
    )
    return f"""
      <section class="section page-shell" aria-labelledby="staged-title">
        <div class="section-heading">
          <div>
            <p class="eyebrow">Unreleased</p>
            <h2 id="staged-title">Held out of the patchset.</h2>
          </div>
          <p>Staged bundles carry the same evidence as accepted ones, but no published patchset applies them and no patched run makes a claim about their subject.</p>
        </div>
        <ul class="staged-list">{items}</ul>
        <p class="section-action"><a class="button button-secondary" href="unreleased/">Open the unreleased set</a></p>
      </section>"""


def render_panel_teaser(panels: list[dict[str, Any]]) -> str:
    if not panels:
        return ""
    features = sum(len(panel["matrix"].get("features", [])) for panel in panels)
    atomic = sum(panel["matrix"].get("coverage", {}).get("atomic_cases", 0) for panel in panels)
    suites = sum(panel["matrix"].get("coverage", {}).get("runtime_suites", 0) for panel in panels)
    if len(panels) == 1:
        lede = (
            f'The <code>{escape(panels[0]["id"])}</code> panel records the state of every mapping '
            "feature the repository has exercised, and names the evidence for each one."
        )
    else:
        lede = (
            f"{len(panels)} panels record the state of every mapping feature the repository has "
            "exercised, and name the evidence for each one."
        )
    return f"""
      <section class="section page-shell" aria-labelledby="panel-title">
        <div class="section-heading">
          <div>
            <p class="eyebrow">Coverage panels</p>
            <h2 id="panel-title">What the mapper does today.</h2>
          </div>
          <p>{lede}</p>
        </div>
        <div class="status-strip status-inline">
          <div class="status-inner">
            <p class="status-item"><strong>{features}</strong> features</p>
            <p class="status-item"><strong>{atomic}</strong> atomic cases</p>
            <p class="status-item"><strong>{suites}</strong> runtime suites</p>
          </div>
        </div>
        <p class="section-action"><a class="button button-secondary" href="panels/">Open the coverage panels</a></p>
      </section>"""


#  Patchsets.


def render_patchset_index(catalog: dict[str, Any]) -> str:
    rows = []
    for patchset in catalog["patchsets"]:
        targets = "".join(
            f'<li><span>GCC {escape(target["gcc_major"])}</span>'
            f'<code>{escape(target["source_version"])}</code>'
            f'{release_badge(target, checked=catalog["publication_checked"])}</li>'
            for target in patchset["targets"]
        )
        marker = pill("current", "Latest") if patchset["latest"] else pill(
            "superseded", f"Superseded by {patchset['superseded_by']}"
        )
        rows.append(
            f"""
          <article class="patchset-card">
            <header>
              <h2><a href="{attribute(patchset['version'] + '/')}">Patchset {escape(patchset['version'])}</a></h2>
              {marker}
            </header>
            <ul class="patchset-targets">{targets}</ul>
          </article>"""
        )

    body = f"""
    <main class="page-shell" id="main">
      {breadcrumbs('../', [('', 'Home')], 'Patchsets')}
      <header class="page-hero">
        <p class="eyebrow">Releases</p>
        <h1>Patchsets.</h1>
        <p>Each patchset pins one GCC source release per supported major and records which bundles it applies, which it runs as controls, and which it holds back.</p>
      </header>
      <div class="patchset-grid">{"".join(rows)}</div>
    </main>"""

    return page(
        title="Patchsets · GNAT patches",
        description="Every published gnat-patches patchset and the GCC releases it covers.",
        depth=1,
        canonical="patchsets/",
        body=body,
        current="patchsets",
    )


def release_badge(target: dict[str, Any], *, checked: bool) -> str:
    if not checked:
        return pill("unknown", "Not checked")
    release = target.get("release")
    if release is None:
        return pill("none", "Not published")
    return pill(release["state"], RELEASE_STATE_LABEL.get(release["state"], release["state"]))


def render_patchset(
    catalog: dict[str, Any], patchset: dict[str, Any], bundles: list[dict[str, Any]]
) -> str:
    prefix = prefix_for(2)
    by_id = {bundle["id"]: bundle for bundle in bundles}
    checked = catalog["publication_checked"]
    version = patchset["version"]

    banner = ""
    if not patchset["latest"]:
        banner = f"""
      <div class="notice notice-superseded">
        <p><strong>Superseded.</strong> Patchset {escape(patchset['superseded_by'])} is newer.
        Bundle detail on this page reflects each bundle's current manifest, not its state when
        {escape(version)} was assembled.</p>
      </div>"""

    cards = []
    for target in patchset["targets"]:
        source = next(
            source for source in catalog["sources"] if source["version"] == target["source_version"]
        )
        pin = definition("Release tag", code(source.get("release_tag", "")))
        pin += definition("Release commit", code(source.get("release_commit", "")))
        pin += definition("Release tree", code(source.get("release_tree", "")))
        cards.append(
            f"""
        <article class="target-card" id="gcc-{escape(target['gcc_major'])}">
          <header>
            <h2>GCC {escape(target['gcc_major'])}</h2>
            <p>Source release <code>{escape(target['source_version'])}</code></p>
          </header>
          {release_panel(target, checked=checked)}
          <dl class="metadata">{pin}</dl>
          {bundle_columns(target, by_id, prefix)}
        </article>"""
        )

    accepted = [bundle for bundle in bundles if bundle["status"] == "accepted"]
    body = f"""
    <main class="page-shell" id="main">
      {breadcrumbs(prefix, [('', 'Home'), ('patchsets/', 'Patchsets')], f'Patchset {version}')}
      <header class="page-hero">
        <p class="eyebrow">{"Latest patchset" if patchset["latest"] else "Earlier patchset"}</p>
        <h1>Patchset {escape(version)}.</h1>
        <p>One pinned GCC source release per supported major, with the bundles this patchset applies to each.</p>
      </header>
      {banner}
      {index_panel(patchset, checked=checked)}
      <section class="section" aria-labelledby="targets-title">
        <h2 id="targets-title" class="section-title">Compilers.</h2>
        <div class="target-grid">{"".join(cards)}</div>
      </section>
      <section class="section" aria-labelledby="matrix-title">
        <h2 id="matrix-title" class="section-title">Bundle roles.</h2>
        {role_matrix(patchset, accepted, prefix, caption=f"Bundle roles in patchset {version}")}
      </section>
      <p class="section-action"><a class="button button-secondary" href="{attribute(prefix)}patchsets/{attribute(version)}.json" download>Patchset JSON</a></p>
    </main>"""

    return page(
        title=f"Patchset {version} · GNAT patches",
        description=f"Bundles, controls, and pinned GCC releases in gnat-patches patchset {version}.",
        depth=2,
        canonical=f"patchsets/{version}/",
        body=body,
        current="patchsets",
    )


def bundle_columns(
    target: dict[str, Any], by_id: dict[str, dict[str, Any]], prefix: str
) -> str:
    def column(title: str, identifiers: list[str], note: str) -> str:
        if not identifiers:
            items = "<li class='is-empty'>None</li>"
        else:
            items = "".join(
                f'<li><a href="{attribute(bundle_href(prefix, identifier))}">'
                f'{escape(by_id[identifier]["title"])}</a></li>'
                for identifier in identifiers
            )
        return (
            f'<div class="bundle-column"><h3>{escape(title)} '
            f'<span class="count">{len(identifiers)}</span></h3>'
            f'<p>{escape(note)}</p><ul>{items}</ul></div>'
        )

    return (
        '<div class="bundle-columns">'
        + column("Patched", target.get("bundles", []), "Applied to this compiler.")
        + column(
            "Controls",
            target.get("control_tests", []),
            "Unpatched here: the release does not have the defect, and the regression proves it.",
        )
        + column(
            "Staged",
            target.get("staged_bundles", []),
            "Held back. This patchset makes no claim about these.",
        )
        + "</div>"
    )


#  Bundles.


def render_bundle_index(catalog: dict[str, Any], intro: str) -> str:
    prefix = prefix_for(1)
    accepted = [bundle for bundle in catalog["bundles"] if bundle["status"] == "accepted"]
    staged = [bundle for bundle in catalog["bundles"] if bundle["status"] == "staged"]

    def table(bundles: list[dict[str, Any]], caption: str) -> str:
        rows = "".join(
            f"""<tr>
              <th scope="row"><a href="{attribute(bundle_href(prefix, bundle['id']))}">{escape(bundle['title'])}</a>
                <span class="role-id"><code>{escape(bundle['id'])}</code></span></th>
              <td>{escape(bundle['problem'])}</td>
              <td>{pill('standalone' if bundle['standalone_patch'] else 'ordered',
                        'Standalone' if bundle['standalone_patch'] else 'Ordered')}</td>
              <td>{escape(bundle.get('introduced_in_patchset') or bundle.get('staged_in_patchset', ''))}</td>
            </tr>"""
            for bundle in bundles
        )
        return f"""
        <div class="table-scroll">
          <table class="bundle-table">
            <caption>{escape(caption)}</caption>
            <thead><tr><th scope="col">Bundle</th><th scope="col">Problem</th><th scope="col">Application</th><th scope="col">Patchset</th></tr></thead>
            <tbody>{rows}</tbody>
          </table>
        </div>"""

    body = f"""
    <main class="page-shell" id="main">
      {breadcrumbs(prefix, [('', 'Home')], 'Bundles')}
      <header class="page-hero">
        <p class="eyebrow">Catalog</p>
        <h1>Bundles.</h1>
        <div class="prose">{intro}</div>
      </header>
      <section class="section" aria-labelledby="accepted-title">
        <h2 id="accepted-title" class="section-title">Accepted.</h2>
        {table(accepted, f"{len(accepted)} accepted bundles")}
      </section>
      <section class="section" aria-labelledby="staged-title">
        <h2 id="staged-title" class="section-title">Staged.</h2>
        <p class="section-lede">These carry complete evidence but are held out of the published patchset. See <a href="{attribute(prefix)}unreleased/">Unreleased</a> for why.</p>
        {table(staged, f"{len(staged)} staged bundles")}
      </section>
    </main>"""

    return page(
        title="Bundles · GNAT patches",
        description="Every GCC patch bundle curated in gnat-patches, accepted and staged.",
        depth=1,
        canonical="bundles/",
        body=body,
        current="bundles",
    )


def render_bundle(
    catalog: dict[str, Any],
    bundle: dict[str, Any],
    *,
    readme: str,
    patches: dict[str, diffs.Patch],
    tests: dict[str, str],
    runner: tuple[str, str] | None,
) -> str:
    prefix = prefix_for(2)
    identifier = bundle["id"]
    status = bundle["status"]

    header_pills = [
        pill(status, STATUS_LABEL.get(status, status)),
        pill(
            "standalone" if bundle["standalone_patch"] else "ordered",
            "Applies standalone" if bundle["standalone_patch"] else "Applies in patchset order",
        ),
    ]
    if bundle.get("introduced_in_patchset"):
        header_pills.append(pill("patchset", f"Since {bundle['introduced_in_patchset']}"))
    if bundle.get("staged_in_patchset"):
        header_pills.append(pill("patchset", f"Staged in {bundle['staged_in_patchset']}"))

    staged_section = ""
    if status == "staged":
        dependencies = bundle.get("staged_depends_on") or []
        links = (
            "".join(
                f'<li><a href="{attribute(bundle_href(prefix, dependency))}">{escape(dependency)}</a></li>'
                for dependency in dependencies
            )
            or "<li class='is-empty'>Nothing</li>"
        )
        staged_section = f"""
      <section class="section notice notice-staged" aria-labelledby="staged-title">
        <h2 id="staged-title" class="section-title">Why this is staged.</h2>
        <p>{escape(bundle.get('staged_reason', ''))}</p>
        <h3>Depends on</h3>
        <ul class="code-list">{links}</ul>
      </section>"""

    variants = "".join(
        render_variant(bundle, variant, patches[variant["id"]], prefix)
        for variant in bundle["variants"]
    )

    def file_actions(hosted: str, repository_path: str) -> str:
        return (
            '<p class="file-action">'
            f'<a href="{attribute(hosted)}" download>Download</a> &middot; '
            f'<a href="{attribute(repository_href(repository_path))}">View in repository</a></p>'
        )

    test_sections = "".join(
        source_fold(
            path,
            source,
            actions=file_actions(
                f"{prefix}bundles/{identifier}/tests/{PurePosixPath(path).name}", path
            ),
        )
        for path, source in tests.items()
    )
    runner_section = ""
    if runner:
        runner_path, runner_source = runner
        runner_section = source_fold(
            runner_path,
            runner_source,
            actions=file_actions(
                f"{prefix}bundles/{identifier}/{PurePosixPath(runner_path).name}", runner_path
            ),
        )

    commands = "".join(
        code_block("shell", bundle[key], label=label)
        for key, label in COMMAND_FIELDS
        if bundle.get(key)
    )

    metadata = "".join(
        definition(label, field_value(bundle[key]))
        for key, label in BUNDLE_FIELDS
        if key in bundle
    )
    remainder = "".join(
        definition(key.replace("_", " ").capitalize(), field_value(value))
        for key, value in sorted(bundle.items())
        if key not in HANDLED_KEYS
    )

    body = f"""
    <main class="page-shell bundle-page" id="main">
      {breadcrumbs(prefix, [('', 'Home'), ('bundles/', 'Bundles')], bundle['title'])}
      <header class="page-hero">
        <p class="eyebrow"><code>{escape(identifier)}</code></p>
        <h1>{escape(bundle['title'])}</h1>
        <p class="hero-lede">{escape(bundle['problem'])}</p>
        <p class="pill-row">{"".join(header_pills)}</p>
        <div class="actions">
          <a class="button button-secondary" href="{attribute(prefix)}bundles/{attribute(identifier)}.json" download>Bundle JSON</a>
          <a class="button button-secondary" href="{attribute(repository_href(bundle['directory']))}">Repository directory</a>
        </div>
      </header>
      {staged_section}
      <section class="section" aria-labelledby="roles-title">
        <h2 id="roles-title" class="section-title">Where it applies.</h2>
        {bundle_role_table(catalog, bundle, prefix)}
      </section>
      <section class="section" aria-labelledby="explanation-title">
        <h2 id="explanation-title" class="section-title">Explanation.</h2>
        <div class="prose">{readme}</div>
      </section>
      <section class="section" aria-labelledby="patch-title">
        <h2 id="patch-title" class="section-title">Patch.</h2>
        {variants}
      </section>
      <section class="section" aria-labelledby="tests-title">
        <h2 id="tests-title" class="section-title">Tests.</h2>
        <dl class="metadata">
          {definition("Before the patch", escape(bundle.get("expected_failure_before_patch", "")))}
          {definition("After the patch", escape(bundle.get("expected_success_after_patch", "")))}
        </dl>
        <div class="fold-stack">{test_sections}{runner_section}</div>
      </section>
      <section class="section" aria-labelledby="commands-title">
        <h2 id="commands-title" class="section-title">Commands.</h2>
        {commands}
      </section>
      <section class="section" aria-labelledby="metadata-title">
        <h2 id="metadata-title" class="section-title">Metadata.</h2>
        <dl class="metadata metadata-wide">{metadata}{remainder}</dl>
      </section>
    </main>"""

    return page(
        title=f"{bundle['title']} · GNAT patches",
        description=bundle["problem"],
        depth=2,
        canonical=f"bundles/{identifier}/",
        body=body,
        current="bundles",
    )


def bundle_role_table(
    catalog: dict[str, Any], bundle: dict[str, Any], prefix: str
) -> str:
    patchsets = catalog["patchsets"]
    majors = sorted({target["gcc_major"] for patchset in patchsets for target in patchset["targets"]})
    head = "".join(f'<th scope="col">GCC {escape(major)}</th>' for major in majors)

    rows = []
    for patchset in patchsets:
        cells = []
        entries = bundle["roles"][patchset["version"]]
        for major in majors:
            entry = entries.get(str(major))
            if entry is None:
                cells.append('<td class="role-cell role-absent"><span class="role-label">Not covered</span></td>')
                continue
            role = entry["role"]
            variant = entry["variant"]
            detail = f'<span class="role-variant">{escape(variant)}</span>' if variant else ""
            source = f'<span class="role-source">{escape(entry["source_version"])}</span>'
            cells.append(
                f'<td class="role-cell role-{attribute(role)}">'
                f'<span class="role-label">{escape(model.ROLE_LABEL[role])}</span>{detail}{source}</td>'
            )
        marker = " (latest)" if patchset["latest"] else ""
        rows.append(
            f'<tr><th scope="row"><a href="{attribute(patchset_href(prefix, patchset["version"]))}">'
            f'{escape(patchset["version"])}{escape(marker)}</a></th>{"".join(cells)}</tr>'
        )

    return f"""
        <div class="table-scroll">
          <table class="role-table role-table-bundle">
            <caption>How each patchset treats this bundle on each GCC major</caption>
            <thead><tr><th scope="col">Patchset</th>{head}</tr></thead>
            <tbody>{"".join(rows)}</tbody>
          </table>
        </div>"""


def render_variant(
    bundle: dict[str, Any], variant: dict[str, Any], patch: diffs.Patch, prefix: str
) -> str:
    identifier = f"{bundle['id']}-{variant['id']}"
    versions = ", ".join(escape(version) for version in variant["versions"])
    flavors = ", ".join(escape(flavor) for flavor in variant.get("source_flavors", []))
    download = f"{prefix}bundles/{bundle['id']}/patches/{PurePosixPath(variant['patch']).name}"

    return f"""
        <article class="variant" id="variant-{attribute(variant['id'])}">
          <header class="variant-header">
            <div>
              <h3>Variant <code>{escape(variant['id'])}</code></h3>
              <p>Applies to {versions}. Source flavors: {flavors or "unrecorded"}.</p>
            </div>
            <p class="variant-stat">
              <span class="diff-added">+{patch.additions}</span>
              <span class="diff-removed">&minus;{patch.deletions}</span>
              <span class="diff-kind">{len(patch.files)} files</span>
            </p>
          </header>
          <dl class="metadata">
            {definition("SHA-256", code(variant['sha256']))}
            {definition("Patch", code(variant['patch']))}
          </dl>
          <p class="file-action"><a href="{attribute(download)}" download>Download the patch</a></p>
          {diffs.render(patch, identifier=identifier)}
        </article>"""


#  Unreleased.


def render_unreleased(catalog: dict[str, Any], staged: list[dict[str, Any]]) -> str:
    prefix = prefix_for(1)
    by_id = {bundle["id"]: bundle for bundle in catalog["bundles"]}

    cards = []
    for bundle in staged:
        dependencies = bundle.get("staged_depends_on") or []
        blocked_by = (
            "".join(
                f'<li><a href="{attribute(bundle_href(prefix, dependency))}">'
                f'{escape(by_id[dependency]["title"])}</a></li>'
                for dependency in dependencies
            )
            or '<li class="is-empty">Nothing. It is staged on its own evidence.</li>'
        )
        blocks = [
            other["id"]
            for other in staged
            if bundle["id"] in (other.get("staged_depends_on") or [])
        ]
        blocking = (
            "".join(
                f'<li><a href="{attribute(bundle_href(prefix, other))}">'
                f'{escape(by_id[other]["title"])}</a></li>'
                for other in blocks
            )
            or '<li class="is-empty">Nothing.</li>'
        )
        cards.append(
            f"""
          <article class="staged-card">
            <header>
              <h2><a href="{attribute(bundle_href(prefix, bundle['id']))}">{escape(bundle['title'])}</a></h2>
              <p class="staged-id"><code>{escape(bundle['id'])}</code></p>
            </header>
            <p>{escape(bundle['problem'])}</p>
            <h3>Why it is held back</h3>
            <p>{escape(bundle.get('staged_reason', ''))}</p>
            <div class="staged-links">
              <div><h3>Depends on</h3><ul>{blocked_by}</ul></div>
              <div><h3>Blocks</h3><ul>{blocking}</ul></div>
            </div>
          </article>"""
        )

    latest = catalog["patchsets"][0]["version"]
    body = f"""
    <main class="page-shell" id="main">
      {breadcrumbs(prefix, [('', 'Home')], 'Unreleased')}
      <header class="page-hero">
        <p class="eyebrow">Not in a published patchset</p>
        <h1>Unreleased.</h1>
        <p>These {len(staged)} bundles carry the same evidence an accepted bundle needs: patch variants for every affected release, an executable regression at <code>-O0</code> and <code>-O2</code>, an explanation with the offending C++ and both Ada outputs, and a coverage panel entry. Patchset {escape(latest)} lists them as staged, applies none of them, and makes no claim about their subject.</p>
      </header>
      <div class="staged-grid">{"".join(cards)}</div>
    </main>"""

    return page(
        title="Unreleased · GNAT patches",
        description="Bundles held out of the published patchset, and what each one is waiting on.",
        depth=1,
        canonical="unreleased/",
        body=body,
        current="unreleased",
    )


#  Panel.


def feature_state_kind(state: str) -> str:
    for kind, states in FEATURE_STATE_KIND.items():
        if state in states:
            return kind
    return "other"


STATE_KIND_LABEL = {
    "verified": "Verified working",
    "patched": "Fixed by a shipped bundle",
    "staged": "Fixed by a staged bundle",
    "limited": "Bounded, not a defect",
    "other": "Other",
}

STATE_KIND_DESCRIPTION = {
    "verified": "Exercised end to end. The generated Ada compiles and behaves as the C++ does.",
    "patched": "A mapper defect with a bundle in the published patchset.",
    "staged": "A mapper defect whose bundle is held out of the published patchset.",
    "limited": "A boundary rather than a defect: Ada cannot represent the construct directly, or the mapper does not emit it.",
    "other": "Recorded without one of the states above.",
}


def render_panel_index(panels: list[dict[str, Any]]) -> str:
    prefix = prefix_for(1)
    cards = []
    for panel in panels:
        features = panel["matrix"].get("features", [])
        coverage = panel["matrix"].get("coverage", {})
        counts: dict[str, int] = {}
        for feature in features:
            kind = feature_state_kind(feature["state"])
            counts[kind] = counts.get(kind, 0) + 1
        states = "".join(
            f'<li class="state-{attribute(kind)}"><span>{counts[kind]}</span>'
            f"{escape(STATE_KIND_LABEL[kind])}</li>"
            for kind in ("verified", "patched", "staged", "limited", "other")
            if kind in counts
        )
        cards.append(
            f"""
          <article class="panel-card">
            <header>
              <h2><a href="{attribute(panel_href(prefix, panel['id']))}">{escape(panel['title'])}</a></h2>
              <p class="panel-id"><code>{escape(panel['id'])}</code></p>
            </header>
            <p>{escape(panel['summary'])}</p>
            <ul class="panel-states">{states}</ul>
            <dl class="metadata">
              {definition("Features", escape(len(features)))}
              {definition("Runtime suites", escape(coverage.get("runtime_suites", 0)))}
              {definition("Compilers", ", ".join(escape(version) for version in panel["matrix"].get("gcc_versions", [])))}
            </dl>
          </article>"""
        )

    body = f"""
    <main class="page-shell" id="main">
      {breadcrumbs(prefix, [('', 'Home')], 'Panels')}
      <header class="page-hero">
        <p class="eyebrow">Evidence</p>
        <h1>Coverage panels.</h1>
        <p>A panel turns exploratory observation into repeatable evidence: it names every feature it exercises, the state that feature is in, and where the proof lives.</p>
      </header>
      <div class="panel-grid">{"".join(cards)}</div>
    </main>"""

    return page(
        title="Panels · GNAT patches",
        description="Coverage panels recording the state and evidence of every mapping feature the repository exercises.",
        depth=1,
        canonical="panels/",
        body=body,
        current="panels",
    )


def render_panel(panel: dict[str, Any], readme: str) -> str:
    prefix = prefix_for(2)
    matrix = panel["matrix"]
    coverage = matrix.get("coverage", {})
    features = matrix.get("features", [])

    categories: dict[str, list[dict[str, Any]]] = {}
    for feature in features:
        categories.setdefault(feature["category"], []).append(feature)

    counts: dict[str, int] = {}
    for feature in features:
        kind = feature_state_kind(feature["state"])
        counts[kind] = counts.get(kind, 0) + 1

    legend = "".join(
        f"""<div class="state-legend-item state-{attribute(kind)}">
          <dt>{escape(STATE_KIND_LABEL[kind])} <span>{counts[kind]}</span></dt>
          <dd>{escape(STATE_KIND_DESCRIPTION[kind])}</dd>
        </div>"""
        for kind in ("verified", "patched", "staged", "limited", "other")
        if kind in counts
    )

    jumps = "".join(
        f'<li><a href="#category-{attribute(category)}">{escape(category_label(category))}'
        f'<span>{len(categories[category])}</span></a></li>'
        for category in sorted(categories)
    )

    sections = []
    for category in sorted(categories):
        rows = []
        for feature in categories[category]:
            state = feature["state"]
            evidence = " ".join(
                render_evidence(reference, prefix) for reference in feature["evidence_references"]
            )
            note = f'<p class="feature-note">{escape(feature["note"])}</p>' if feature.get("note") else ""
            rows.append(
                f"""<tr>
                  <th scope="row"><code>{escape(feature['id'])}</code></th>
                  <td class="feature-state feature-{attribute(feature_state_kind(state))}">
                    {escape(model.feature_state_label(state))}</td>
                  <td>{evidence}{note}</td>
                </tr>"""
            )
        sections.append(
            f"""
        <section class="section" aria-labelledby="category-{attribute(category)}">
          <h2 id="category-{attribute(category)}" class="section-title">{escape(category_label(category))}.</h2>
          <div class="table-scroll">
            <table class="feature-table">
              <caption>{len(categories[category])} features</caption>
              <thead><tr><th scope="col">Feature</th><th scope="col">State</th><th scope="col">Evidence</th></tr></thead>
              <tbody>{"".join(rows)}</tbody>
            </table>
          </div>
        </section>"""
        )

    suites = "".join(
        f'<li><a href="{attribute(repository_href(suite))}"><code>{escape(suite)}</code></a></li>'
        for suite in coverage_suites(panel)
    )
    options = ", ".join(f"<code>{escape(option)}</code>" for option in matrix.get("driver_options", []))
    versions = ", ".join(escape(version) for version in matrix.get("gcc_versions", []))

    method = ""
    if readme:
        method = f"""
      <section class="section" aria-labelledby="method-title">
        <h2 id="method-title" class="section-title">Method.</h2>
        <details class="disclosure">
          <summary>
            <span class="disclosure-title">How the panel is built, and what it deliberately bounds</span>
            <span class="disclosure-hint">The panel's own notes: probe layers, run states, target boundaries, and the limits it records rather than hides.</span>
          </summary>
          <div class="prose">{readme}</div>
        </details>
      </section>"""

    body = f"""
    <main class="page-shell" id="main">
      {breadcrumbs(prefix, [('', 'Home'), ('panels/', 'Panels')], panel['title'])}
      <header class="page-hero">
        <p class="eyebrow">Panel <code>{escape(panel['id'])}</code></p>
        <h1>{escape(panel['title'])}</h1>
        <p>{escape(panel['summary'])} Driver options: {options or "unrecorded"}. Compilers: {versions}.</p>
        <div class="actions">
          <a class="button button-secondary" href="{attribute(prefix)}panels/{attribute(panel['id'])}.json" download>Panel JSON</a>
        </div>
      </header>
      <div class="status-strip status-inline">
        <div class="status-inner">
          <p class="status-item"><strong>{len(features)}</strong> features</p>
          <p class="status-item"><strong>{escape(coverage.get('atomic_cases', 0))}</strong> atomic cases</p>
          <p class="status-item"><strong>{escape(coverage.get('pairwise_cases', 0))}</strong> pairwise cases</p>
          <p class="status-item"><strong>{escape(coverage.get('grammar_cases', 0))}</strong> grammar cases</p>
          <p class="status-item"><strong>{escape(coverage.get('runtime_suites', 0))}</strong> runtime suites</p>
        </div>
      </div>
      <section class="section" aria-labelledby="states-title">
        <h2 id="states-title" class="section-title">States.</h2>
        <dl class="state-legend">{legend}</dl>
        <nav class="category-nav" aria-label="Feature categories">
          <ul>{jumps}</ul>
        </nav>
      </section>
      {"".join(sections)}
      <section class="section" aria-labelledby="suites-title">
        <h2 id="suites-title" class="section-title">Runtime suites.</h2>
        <p class="section-lede">Each suite links C++ and Ada and runs at <code>-O0</code> and <code>-O2</code>.</p>
        <ul class="code-list suite-list">{suites}</ul>
      </section>
      {method}
    </main>"""

    return page(
        title=f"{panel['title']} · GNAT patches",
        description=panel["summary"],
        depth=2,
        canonical=f"panels/{panel['id']}/",
        body=body,
        current="panels",
    )


def category_label(category: str) -> str:
    return category.replace("-", " ").capitalize()


def coverage_suites(panel: dict[str, Any]) -> list[str]:
    return list(panel["coverage"].get("runtime", {}).get("suites", []))


def render_evidence(reference: dict[str, Any], prefix: str) -> str:
    cases = "".join(f'<code class="evidence-case">{escape(case)}</code>' for case in reference["cases"])
    if reference["bundle"]:
        target = bundle_href(prefix, reference["bundle"])
        label = reference["bundle"]
    else:
        target = repository_href(reference["path"])
        label = reference["path"]
    return f'<a class="evidence" href="{attribute(target)}"><code>{escape(label)}</code></a>{cases}'
