"""Parse and render the unified diffs a bundle ships.

A patch is published as structure rather than as a wall of text: one panel per
touched file, hunks with their original line numbers, and the payload of every
line highlighted in the language of the file it belongs to. Highlighting state
carries across the lines of a hunk so a C++ block comment spanning a hunk stays
one comment.

Anything the parser does not recognise raises DiffError. A patch that this
module cannot read completely is never published as a partial diff.
"""

from __future__ import annotations

import html
import re
from dataclasses import dataclass, field

from . import highlight


class DiffError(ValueError):
    """Raised when a patch file cannot be parsed as a unified diff."""


HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@ ?(.*)$")
GIT_HEADER = re.compile(r"^diff --git a/(.+) b/(.+)$")


@dataclass
class DiffLine:
    kind: str  #  "context", "insert", "delete", or "note"
    text: str
    old_number: int | None = None
    new_number: int | None = None


@dataclass
class Hunk:
    old_start: int
    new_start: int
    section: str
    lines: list[DiffLine] = field(default_factory=list)


@dataclass
class FileDiff:
    path: str
    kind: str  #  "added", "deleted", or "modified"
    hunks: list[Hunk] = field(default_factory=list)
    additions: int = 0
    deletions: int = 0

    @property
    def language(self) -> str:
        return highlight.language_for_path(self.path)


@dataclass
class Patch:
    files: list[FileDiff] = field(default_factory=list)

    @property
    def additions(self) -> int:
        return sum(file.additions for file in self.files)

    @property
    def deletions(self) -> int:
        return sum(file.deletions for file in self.files)


def parse(text: str) -> Patch:
    """Return TEXT parsed as a git-style unified diff."""
    patch = Patch()
    current: FileDiff | None = None
    hunk: Hunk | None = None
    old_number = new_number = 0
    lines = text.split("\n")
    position = 0

    while position < len(lines):
        line = lines[position]

        header = GIT_HEADER.match(line)
        if header:
            current = FileDiff(path=header.group(2), kind="modified")
            patch.files.append(current)
            hunk = None
            position += 1
            continue

        if current is None:
            if line.strip():
                raise DiffError(f"diff content precedes any file header: {line!r}")
            position += 1
            continue

        if line.startswith("new file mode"):
            current.kind = "added"
            position += 1
            continue

        if line.startswith("deleted file mode"):
            current.kind = "deleted"
            position += 1
            continue

        if line.startswith(("index ", "similarity index", "old mode", "new mode")):
            position += 1
            continue

        if line.startswith("--- "):
            position += 1
            continue

        if line.startswith("+++ "):
            target = line[4:].strip()
            if target != "/dev/null":
                current.path = target[2:] if target.startswith("b/") else target
            position += 1
            continue

        boundary = HUNK.match(line)
        if boundary:
            old_number = int(boundary.group(1))
            new_number = int(boundary.group(3))
            hunk = Hunk(
                old_start=old_number,
                new_start=new_number,
                section=boundary.group(5).strip(),
            )
            current.hunks.append(hunk)
            position += 1
            continue

        if hunk is None:
            if not line.strip():
                position += 1
                continue
            raise DiffError(f"diff body precedes any hunk header: {line!r}")

        if line.startswith("\\"):
            hunk.lines.append(DiffLine(kind="note", text=line[1:].strip()))
            position += 1
            continue

        marker, payload = (line[:1], line[1:]) if line else (" ", "")
        if marker == "+":
            hunk.lines.append(DiffLine(kind="insert", text=payload, new_number=new_number))
            new_number += 1
            current.additions += 1
        elif marker == "-":
            hunk.lines.append(DiffLine(kind="delete", text=payload, old_number=old_number))
            old_number += 1
            current.deletions += 1
        elif marker == " ":
            hunk.lines.append(
                DiffLine(
                    kind="context",
                    text=payload,
                    old_number=old_number,
                    new_number=new_number,
                )
            )
            old_number += 1
            new_number += 1
        elif not line.strip():
            #  A trailing empty line inside a hunk is an unchanged empty line.
            hunk.lines.append(
                DiffLine(kind="context", text="", old_number=old_number, new_number=new_number)
            )
            old_number += 1
            new_number += 1
        else:
            raise DiffError(f"unrecognised diff line: {line!r}")

        position += 1

    if not patch.files:
        raise DiffError("patch contains no file headers")
    for file in patch.files:
        if not file.hunks:
            raise DiffError(f"patch declares {file.path} without any hunk")
    return patch


KIND_LABEL = {"added": "new file", "deleted": "deleted file", "modified": "modified"}
MARKER = {"context": " ", "insert": "+", "delete": "-", "note": ""}
ROW_LABEL = {"insert": "Added line", "delete": "Removed line"}


def render(patch: Patch, *, identifier: str) -> str:
    """Return PATCH as HTML, with IDENTIFIER seeding per-file anchors."""
    return "".join(
        _render_file(file, f"{identifier}-{index}") for index, file in enumerate(patch.files, 1)
    )


def _render_file(file: FileDiff, anchor: str) -> str:
    rows = []
    for hunk in file.hunks:
        rows.append(
            '<tr class="diff-hunk-row"><td colspan="4">'
            f'<span class="diff-hunk-range">@@ -{hunk.old_start} +{hunk.new_start} @@</span>'
            + (f'<span class="diff-hunk-section">{html.escape(hunk.section)}</span>' if hunk.section else "")
            + "</td></tr>"
        )
        state = highlight.CLEAN
        for line in hunk.lines:
            if line.kind == "note":
                rows.append(
                    '<tr class="diff-note"><td colspan="4">'
                    f"{html.escape(line.text)}</td></tr>"
                )
                continue
            markup, state = highlight.highlight_line(file.language, line.text, state)
            label = ROW_LABEL.get(line.kind, "")
            prefix = f'<span class="visually-hidden">{label}. </span>' if label else ""
            rows.append(
                f'<tr class="diff-line diff-{line.kind}">'
                f'<td class="diff-number">{line.old_number or ""}</td>'
                f'<td class="diff-number">{line.new_number or ""}</td>'
                f'<td class="diff-marker" aria-hidden="true">{MARKER[line.kind]}</td>'
                f'<td class="diff-code">{prefix}<code>{markup}</code></td>'
                "</tr>"
            )

    stat = (
        f'<span class="diff-added">+{file.additions}</span>'
        f'<span class="diff-removed">−{file.deletions}</span>'
        f'<span class="diff-kind">{KIND_LABEL[file.kind]}</span>'
    )
    #  A file diff opens by default: the patch is what the page is about. It
    #  still folds, because one bundle can touch several long files.
    return f"""
      <details class="fold fold-diff" id="{html.escape(anchor, quote=True)}" open>
        <summary>
          <span class="fold-name"><code>{html.escape(file.path)}</code></span>
          <span class="diff-stat">{stat}</span>
        </summary>
        <div class="table-scroll">
          <table class="diff-table">
            <caption class="visually-hidden">Unified diff for {html.escape(file.path)}: original line, patched line, change, source</caption>
            <tbody>{"".join(rows)}</tbody>
          </table>
        </div>
      </details>"""
