"""Render repository Markdown to HTML at build time.

The renderer follows CommonMark for the constructs the repository uses:
ATX and setext headings, paragraphs, fenced and indented code, block quotes,
nested ordered and unordered lists, thematic breaks, GitHub tables, and the
inline set of code spans, links, images, autolinks, emphasis, strong emphasis,
backslash escapes, and hard line breaks.

Raw HTML is deliberately unsupported. Bundle prose is dense with C++ template
spellings such as ``vector<int>``, and CommonMark would parse ``<int>`` as a
tag and delete it from the page. Every angle bracket is escaped instead, and a
line that opens a block-level HTML element fails rendering rather than being
published as literal text.

Emphasis follows CommonMark's flanking rules, which is what keeps Ada
identifiers intact: ``External_Name`` and ``C_Pass_By_Copy`` contain
intraword underscores that never open or close emphasis.
"""

from __future__ import annotations

import html
import re
from dataclasses import dataclass, field
from typing import Callable


class MarkdownError(ValueError):
    """Raised when a document uses a construct the renderer will not publish."""


HighlightFunction = Callable[[str, str], str]
LinkResolver = Callable[[str], str]

BLOCK_HTML = re.compile(r"^ {0,3}</?[A-Za-z][A-Za-z0-9-]*(?:[\s/>]|$)")
THEMATIC_BREAK = re.compile(r"^ {0,3}(?:(?:\*[ \t]*){3,}|(?:-[ \t]*){3,}|(?:_[ \t]*){3,})$")
ATX_HEADING = re.compile(r"^ {0,3}(#{1,6})(?:[ \t]+(.*?))?(?:[ \t]+#+)?[ \t]*$")
SETEXT_UNDERLINE = re.compile(r"^ {0,3}(=+|-+)[ \t]*$")
FENCE = re.compile(r"^( {0,3})(`{3,}|~{3,})[ \t]*([^`\s]*)[^`]*$")
BULLET = re.compile(r"^( {0,3})([-+*])(?:([ \t]+)(.*))?$")
ORDERED = re.compile(r"^( {0,3})(\d{1,9})([.)])(?:([ \t]+)(.*))?$")
BLOCK_QUOTE = re.compile(r"^ {0,3}>[ \t]?(.*)$")
TABLE_DELIMITER = re.compile(r"^ {0,3}\|?[ \t]*:?-+:?[ \t]*(?:\|[ \t]*:?-+:?[ \t]*)*\|?[ \t]*$")


def render(
    text: str,
    *,
    highlight: HighlightFunction | None = None,
    heading_offset: int = 0,
    link_resolver: LinkResolver | None = None,
) -> str:
    """Return TEXT rendered as HTML.

    HIGHLIGHT receives a fenced block's info string and its literal content and
    returns the escaped HTML for the code element. Fences without a highlighter
    fall back to plain escaped text. HEADING_OFFSET demotes every heading, so a
    document embedded under a page section keeps one outline. LINK_RESOLVER
    rewrites every link destination, which is how repository-relative links in
    a README become links between published pages.
    """
    document = _Document(
        highlight=highlight or _plain_code,
        heading_offset=heading_offset,
        link_resolver=link_resolver,
    )
    return document.render(text)


def strip_first_heading(text: str) -> str:
    """Return TEXT without its first heading, which the page shows as a title."""
    lines = _expand(text).split("\n")
    for position, line in enumerate(lines):
        if ATX_HEADING.match(line):
            return "\n".join(lines[:position] + lines[position + 1:]).lstrip("\n")
        following = lines[position + 1] if position + 1 < len(lines) else ""
        if line.strip() and SETEXT_UNDERLINE.match(following) and not FENCE.match(line):
            return "\n".join(lines[:position] + lines[position + 2:]).lstrip("\n")
    return text


def first_heading(text: str) -> str | None:
    """Return the plain text of the document's first ATX or setext heading."""
    lines = _expand(text).split("\n")
    for position, line in enumerate(lines):
        atx = ATX_HEADING.match(line)
        if atx:
            return _plain_inline(atx.group(2) or "")
        following = lines[position + 1] if position + 1 < len(lines) else ""
        if line.strip() and SETEXT_UNDERLINE.match(following) and not FENCE.match(line):
            return _plain_inline(line.strip())
    return None


def first_paragraph(text: str) -> str:
    """Return the document's first paragraph as one line of plain text."""
    lines = _expand(text).split("\n")
    collected: list[str] = []
    for position, line in enumerate(lines):
        if ATX_HEADING.match(line) or FENCE.match(line):
            if collected:
                break
            continue
        if not line.strip():
            if collected:
                break
            continue
        following = lines[position + 1] if position + 1 < len(lines) else ""
        if SETEXT_UNDERLINE.match(following) and not collected:
            continue
        if SETEXT_UNDERLINE.match(line) and not collected:
            continue
        collected.append(line.strip())
    return _plain_inline(" ".join(collected))


def _plain_code(info: str, code: str) -> str:
    del info
    return html.escape(code, quote=False)


def _expand(text: str) -> str:
    return text.replace("\r\n", "\n").replace("\r", "\n").replace("\t", "    ")


def _plain_inline(text: str) -> str:
    """Return TEXT with inline markup removed, for titles and descriptions."""
    without_code = re.sub(r"`+([^`]*)`+", r"\1", text)
    without_links = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", without_code)
    without_emphasis = re.sub(r"(\*{1,2})(\S(?:.*?\S)?)\1", r"\2", without_links)
    return re.sub(r"\\(.)", r"\1", without_emphasis).strip()


@dataclass
class _ListItem:
    lines: list[str] = field(default_factory=list)
    indent: int = 0


@dataclass
class _ListBlock:
    ordered: bool
    start: int
    delimiter: str
    items: list[_ListItem] = field(default_factory=list)
    loose: bool = False


class _Document:
    def __init__(
        self,
        *,
        highlight: HighlightFunction,
        heading_offset: int = 0,
        link_resolver: LinkResolver | None = None,
    ) -> None:
        self.highlight = highlight
        self.heading_offset = heading_offset
        self.link_resolver = link_resolver
        self.slugs: dict[str, int] = {}

    def render(self, text: str) -> str:
        lines = _expand(text).split("\n")
        return self.blocks(lines)

    #  Block structure.

    def blocks(self, lines: list[str]) -> str:
        parts: list[str] = []
        paragraph: list[str] = []
        position = 0

        def flush_paragraph() -> None:
            if paragraph:
                content = "\n".join(paragraph).strip()
                if content:
                    parts.append(f"<p>{self.inline(content)}</p>")
                paragraph.clear()

        while position < len(lines):
            line = lines[position]

            if not line.strip():
                flush_paragraph()
                position += 1
                continue

            if BLOCK_HTML.match(line):
                raise MarkdownError(
                    f"raw HTML is not published by this renderer: {line.strip()!r}"
                )

            fence = FENCE.match(line)
            if fence:
                flush_paragraph()
                position = self.fenced_code(lines, position, fence, parts)
                continue

            if THEMATIC_BREAK.match(line):
                flush_paragraph()
                parts.append("<hr>")
                position += 1
                continue

            heading = ATX_HEADING.match(line)
            if heading:
                flush_paragraph()
                level = min(6, len(heading.group(1)) + self.heading_offset)
                text = (heading.group(2) or "").strip()
                content = self.inline(text)
                parts.append(self.heading(level, text, content))
                position += 1
                continue

            if paragraph and SETEXT_UNDERLINE.match(line):
                level = min(6, (1 if line.strip().startswith("=") else 2) + self.heading_offset)
                text = "\n".join(paragraph).strip()
                content = self.inline(text)
                paragraph.clear()
                parts.append(self.heading(level, text, content))
                position += 1
                continue

            if BLOCK_QUOTE.match(line):
                flush_paragraph()
                position = self.block_quote(lines, position, parts)
                continue

            if self.starts_table(lines, position):
                flush_paragraph()
                position = self.table(lines, position, parts)
                continue

            if self.starts_list(line):
                flush_paragraph()
                position = self.list_block(lines, position, parts)
                continue

            if not paragraph and line.startswith("    "):
                flush_paragraph()
                position = self.indented_code(lines, position, parts)
                continue

            paragraph.append(line)
            position += 1

        flush_paragraph()
        return "".join(parts)

    def starts_list(self, line: str) -> bool:
        bullet = BULLET.match(line)
        if bullet and not THEMATIC_BREAK.match(line):
            return bullet.group(3) is not None or bullet.group(4) is None
        ordered = ORDERED.match(line)
        if ordered:
            return ordered.group(4) is not None or ordered.group(5) is None
        return False

    def fenced_code(
        self, lines: list[str], position: int, fence: re.Match[str], parts: list[str]
    ) -> int:
        indent, marker, info = fence.group(1), fence.group(2), fence.group(3)
        closing = re.compile(rf"^ {{0,3}}{marker[0]}{{{len(marker)},}}[ \t]*$")
        body: list[str] = []
        position += 1
        while position < len(lines) and not closing.match(lines[position]):
            line = lines[position]
            body.append(line[len(indent):] if line.startswith(indent) else line.lstrip())
            position += 1
        if position >= len(lines):
            raise MarkdownError("fenced code block is never closed")
        code = "\n".join(body)
        language = info.strip()
        rendered = self.highlight(language, code)
        attribute = f' class="language-{html.escape(_language_slug(language), quote=True)}"' if language else ""
        parts.append(
            f'<div class="code-panel"><pre><code{attribute}>{rendered}</code></pre></div>'
        )
        return position + 1

    def indented_code(self, lines: list[str], position: int, parts: list[str]) -> int:
        body: list[str] = []
        while position < len(lines):
            line = lines[position]
            if line.startswith("    "):
                body.append(line[4:])
            elif not line.strip():
                body.append("")
            else:
                break
            position += 1
        while body and not body[-1].strip():
            body.pop()
        code = self.highlight("", "\n".join(body))
        parts.append(f'<div class="code-panel"><pre><code>{code}</code></pre></div>')
        return position

    def block_quote(self, lines: list[str], position: int, parts: list[str]) -> int:
        body: list[str] = []
        while position < len(lines):
            quoted = BLOCK_QUOTE.match(lines[position])
            if quoted:
                body.append(quoted.group(1))
            elif lines[position].strip() and body:
                body.append(lines[position])
            else:
                break
            position += 1
        parts.append(f"<blockquote>{self.blocks(body)}</blockquote>")
        return position

    def starts_table(self, lines: list[str], position: int) -> bool:
        if "|" not in lines[position]:
            return False
        following = lines[position + 1] if position + 1 < len(lines) else ""
        return bool(TABLE_DELIMITER.match(following)) and "|" in following

    def table(self, lines: list[str], position: int, parts: list[str]) -> int:
        header = _table_cells(lines[position])
        alignments = [_alignment(cell) for cell in _table_cells(lines[position + 1])]
        position += 2
        rows: list[list[str]] = []
        while position < len(lines) and lines[position].strip() and "|" in lines[position]:
            rows.append(_table_cells(lines[position]))
            position += 1

        def cell(tag: str, value: str, column: int) -> str:
            align = alignments[column] if column < len(alignments) else ""
            attribute = f' style="text-align:{align}"' if align else ""
            return f"<{tag}{attribute}>{self.inline(value)}</{tag}>"

        head = "".join(cell("th", value, column) for column, value in enumerate(header))
        body = "".join(
            "<tr>" + "".join(cell("td", value, column) for column, value in enumerate(row)) + "</tr>"
            for row in rows
        )
        parts.append(
            '<div class="table-scroll"><table class="prose-table">'
            f"<thead><tr>{head}</tr></thead><tbody>{body}</tbody></table></div>"
        )
        return position

    def list_block(self, lines: list[str], position: int, parts: list[str]) -> int:
        first = lines[position]
        ordered_match = ORDERED.match(first)
        ordered = ordered_match is not None
        block = _ListBlock(
            ordered=ordered,
            start=int(ordered_match.group(2)) if ordered_match else 1,
            delimiter=ordered_match.group(3) if ordered_match else BULLET.match(first).group(2),
        )
        blank_before_item = False

        while position < len(lines):
            line = lines[position]
            if not line.strip():
                if not block.items:
                    break
                lookahead = position + 1
                while lookahead < len(lines) and not lines[lookahead].strip():
                    lookahead += 1
                if lookahead >= len(lines):
                    position = lookahead
                    break
                following = lines[lookahead]
                indented = following.startswith(" " * block.items[-1].indent)
                if not self.starts_list(following) and not indented:
                    position = lookahead
                    break
                if self.starts_list(following) and not self.same_kind(block, following):
                    position = lookahead
                    break
                block.items[-1].lines.append("")
                blank_before_item = True
                position += 1
                continue

            if self.starts_list(line):
                if not self.same_kind(block, line):
                    break
                marker = ORDERED.match(line) if block.ordered else BULLET.match(line)
                indent = len(marker.group(1))
                if block.items and indent >= block.items[-1].indent:
                    block.items[-1].lines.append(line[block.items[-1].indent:])
                    position += 1
                    continue
                if block.ordered:
                    content = marker.group(5) or ""
                    width = indent + len(marker.group(2)) + 1 + len(marker.group(4) or " ")
                else:
                    content = marker.group(4) or ""
                    width = indent + 1 + len(marker.group(3) or " ")
                block.items.append(_ListItem(lines=[content], indent=width))
                if blank_before_item:
                    block.loose = True
                blank_before_item = False
                position += 1
                continue

            if block.items:
                item = block.items[-1]
                item.lines.append(line[item.indent:] if line.startswith(" " * item.indent) else line.lstrip())
                position += 1
                continue

            break

        rendered_items = []
        for item in block.items:
            body = list(item.lines)
            while body and not body[-1].strip():
                body.pop()
            if _is_loose(body):
                block.loose = True
            rendered_items.append(body)

        chunks = []
        for body in rendered_items:
            content = self.blocks(body)
            if not block.loose:
                content = _unwrap_leading_paragraph(content)
            chunks.append(f"<li>{content}</li>")

        if block.ordered:
            start = f' start="{block.start}"' if block.start != 1 else ""
            parts.append(f"<ol{start}>{''.join(chunks)}</ol>")
        else:
            parts.append(f"<ul>{''.join(chunks)}</ul>")
        return position

    def same_kind(self, block: _ListBlock, line: str) -> bool:
        ordered = ORDERED.match(line)
        if block.ordered:
            return ordered is not None and ordered.group(3) == block.delimiter
        bullet = BULLET.match(line)
        return ordered is None and bullet is not None and bullet.group(2) == block.delimiter

    def heading(self, level: int, text: str, content: str) -> str:
        identifier = self.slug(text)
        return f'<h{level} id="{html.escape(identifier, quote=True)}">{content}</h{level}>'

    def slug(self, text: str) -> str:
        base = re.sub(r"[^a-z0-9 -]+", "", _plain_inline(text).lower())
        base = re.sub(r"[ ]+", "-", base.strip()) or "section"
        seen = self.slugs.get(base, 0)
        self.slugs[base] = seen + 1
        return base if not seen else f"{base}-{seen}"

    #  Inline structure.

    def inline(self, text: str) -> str:
        return _inline(text, self.link_resolver)


def _language_slug(info: str) -> str:
    return re.sub(r"[^a-z0-9+-]+", "-", info.strip().lower()) or "text"


def _is_loose(lines: list[str]) -> bool:
    seen_blank = False
    for line in lines[1:]:
        if not line.strip():
            seen_blank = True
        elif seen_blank:
            return True
    return False


def _unwrap_leading_paragraph(content: str) -> str:
    if not content.startswith("<p>"):
        return content
    closing = content.find("</p>")
    if closing == -1:
        return content
    return content[3:closing] + content[closing + 4:]


def _table_cells(line: str) -> list[str]:
    stripped = line.strip()
    if stripped.startswith("|"):
        stripped = stripped[1:]
    if stripped.endswith("|") and not stripped.endswith("\\|"):
        stripped = stripped[:-1]
    cells: list[str] = []
    current = ""
    escaped = False
    for character in stripped:
        if escaped:
            current += character
            escaped = False
        elif character == "\\":
            current += character
            escaped = True
        elif character == "|":
            cells.append(current.strip())
            current = ""
        else:
            current += character
    cells.append(current.strip())
    return cells


def _alignment(cell: str) -> str:
    value = cell.strip()
    if value.startswith(":") and value.endswith(":"):
        return "center"
    if value.endswith(":"):
        return "right"
    if value.startswith(":"):
        return "left"
    return ""


#  Inline parsing: a delimiter run stack over a token list, as CommonMark
#  describes it, restricted to the constructs this repository writes.

PUNCTUATION = set("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")


@dataclass
class _Token:
    kind: str  #  "text", "html", or "delim"
    value: str
    delimiter: str = ""
    length: int = 0
    can_open: bool = False
    can_close: bool = False
    active: bool = True


def _inline(text: str, link_resolver: LinkResolver | None = None) -> str:
    tokens = _tokenize(text, link_resolver)
    _resolve_emphasis(tokens)
    return "".join(token.value for token in tokens)


def _tokenize(text: str, link_resolver: LinkResolver | None = None) -> list[_Token]:
    tokens: list[_Token] = []
    position = 0
    length = len(text)

    def emit_text(value: str) -> None:
        if not value:
            return
        if tokens and tokens[-1].kind == "text":
            tokens[-1].value += html.escape(value, quote=False)
        else:
            tokens.append(_Token("text", html.escape(value, quote=False)))

    while position < length:
        character = text[position]

        if character == "\\" and position + 1 < length:
            following = text[position + 1]
            if following == "\n":
                tokens.append(_Token("html", "<br>"))
                position += 2
                continue
            if following in PUNCTUATION:
                emit_text(following)
                position += 2
                continue
            emit_text(character)
            position += 1
            continue

        if character == "`":
            match = re.compile(r"`+").match(text, position)
            marker = match.group(0)
            closing = text.find(marker, match.end())
            while closing != -1 and _run_length(text, closing) != len(marker):
                closing = text.find(marker, closing + _run_length(text, closing))
            if closing != -1:
                code = text[match.end():closing]
                code = code.replace("\n", " ")
                if code.startswith(" ") and code.endswith(" ") and code.strip():
                    code = code[1:-1]
                tokens.append(
                    _Token("html", f"<code>{html.escape(code, quote=False)}</code>")
                )
                position = closing + len(marker)
                continue
            emit_text(marker)
            position = match.end()
            continue

        if character == "<":
            autolink = re.compile(r"<((?:https?|mailto):[^ <>]+)>").match(text, position)
            if autolink:
                target = autolink.group(1)
                escaped = html.escape(target, quote=True)
                tokens.append(_Token("html", f'<a href="{escaped}">{escaped}</a>'))
                position = autolink.end()
                continue
            email = re.compile(r"<([^ <>@]+@[^ <>@]+\.[^ <>@]+)>").match(text, position)
            if email:
                target = html.escape(email.group(1), quote=True)
                tokens.append(_Token("html", f'<a href="mailto:{target}">{target}</a>'))
                position = email.end()
                continue
            emit_text(character)
            position += 1
            continue

        if character in "!["  and (character == "[" or text[position:position + 2] == "!["):
            link = _match_link(text, position, link_resolver)
            if link:
                rendered, position = link
                tokens.append(_Token("html", rendered))
                continue
            emit_text(character)
            position += 1
            continue

        if character in "*_":
            run = _run_length(text, position)
            before = text[position - 1] if position else "\n"
            after = text[position + run] if position + run < length else "\n"
            can_open, can_close = _flanking(character, before, after)
            tokens.append(
                _Token(
                    "delim",
                    html.escape(character * run, quote=False),
                    delimiter=character,
                    length=run,
                    can_open=can_open,
                    can_close=can_close,
                )
            )
            position += run
            continue

        if character == "\n":
            if text[max(0, position - 2):position] == "  ":
                if tokens and tokens[-1].kind == "text":
                    tokens[-1].value = tokens[-1].value.rstrip(" ")
                tokens.append(_Token("html", "<br>"))
            else:
                emit_text("\n")
            position += 1
            continue

        following = re.compile(r"[^\\`<*_\n\[!]+").match(text, position)
        if following:
            emit_text(following.group(0))
            position = following.end()
            continue

        emit_text(character)
        position += 1

    return tokens


def _run_length(text: str, position: int) -> int:
    character = text[position]
    length = 0
    while position + length < len(text) and text[position + length] == character:
        length += 1
    return length


def _flanking(character: str, before: str, after: str) -> tuple[bool, bool]:
    after_whitespace = after.isspace()
    before_whitespace = before.isspace()
    after_punctuation = after in PUNCTUATION
    before_punctuation = before in PUNCTUATION

    left = not after_whitespace and (
        not after_punctuation or before_whitespace or before_punctuation
    )
    right = not before_whitespace and (
        not before_punctuation or after_whitespace or after_punctuation
    )
    if character == "_":
        #  Intraword underscores never delimit emphasis, which is what keeps
        #  Ada identifiers such as C_Pass_By_Copy intact.
        return left and (not right or before_punctuation), right and (not left or after_punctuation)
    return left, right


def _match_link(
    text: str, position: int, link_resolver: LinkResolver | None = None
) -> tuple[str, int] | None:
    image = text[position] == "!"
    start = position + 1 if image else position
    if start >= len(text) or text[start] != "[":
        return None
    depth = 0
    index = start
    while index < len(text):
        if text[index] == "\\":
            index += 2
            continue
        if text[index] == "[":
            depth += 1
        elif text[index] == "]":
            depth -= 1
            if depth == 0:
                break
        index += 1
    if index >= len(text) or index + 1 >= len(text) or text[index + 1] != "(":
        return None
    label = text[start + 1:index]
    closing = text.find(")", index + 2)
    if closing == -1:
        return None
    destination = text[index + 2:closing].strip()
    title = ""
    title_match = re.search(r'\s+"([^"]*)"$', destination)
    if title_match:
        title = title_match.group(1)
        destination = destination[: title_match.start()].strip()
    if destination.startswith("<") and destination.endswith(">"):
        destination = destination[1:-1]
    if re.match(r"^\s*javascript:", destination, re.IGNORECASE):
        raise MarkdownError(f"unsupported link destination: {destination!r}")
    if link_resolver:
        destination = link_resolver(destination)
    href = html.escape(destination, quote=True)
    attribute = f' title="{html.escape(title, quote=True)}"' if title else ""
    if image:
        alt = html.escape(_plain_inline(label), quote=True)
        return f'<img src="{href}" alt="{alt}"{attribute}>', closing + 1
    return f'<a href="{href}"{attribute}>{_inline(label, link_resolver)}</a>', closing + 1


def _resolve_emphasis(tokens: list[_Token]) -> None:
    index = 0
    while index < len(tokens):
        closer = tokens[index]
        if closer.kind != "delim" or not closer.active or not closer.can_close:
            index += 1
            continue
        opener_index = _find_opener(tokens, index)
        if opener_index is None:
            index += 1
            continue

        opener = tokens[opener_index]
        strong = opener.length >= 2 and closer.length >= 2
        width = 2 if strong else 1
        tag = "strong" if strong else "em"

        opener.length -= width
        closer.length -= width
        opener.value = html.escape(opener.delimiter * opener.length, quote=False)
        closer.value = html.escape(closer.delimiter * closer.length, quote=False)
        opener.active = opener.length > 0
        closer.active = closer.length > 0

        for between in tokens[opener_index + 1:index]:
            if between.kind == "delim":
                between.active = False

        tokens.insert(index, _Token("html", f"</{tag}>"))
        tokens.insert(opener_index + 1, _Token("html", f"<{tag}>"))
        index = opener_index + 1

def _find_opener(tokens: list[_Token], closer_index: int) -> int | None:
    closer = tokens[closer_index]
    for index in range(closer_index - 1, -1, -1):
        candidate = tokens[index]
        if candidate.kind != "delim" or not candidate.active:
            continue
        if candidate.delimiter != closer.delimiter or not candidate.can_open:
            continue
        #  CommonMark's rule of three keeps runs such as ***a*** balanced.
        if (candidate.can_close or closer.can_open) and (
            candidate.length + closer.length
        ) % 3 == 0 and candidate.length % 3 != 0:
            continue
        return index
    return None
