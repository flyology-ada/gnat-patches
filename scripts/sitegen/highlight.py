"""Syntax highlighting performed at build time.

Every code sample the site publishes is highlighted here rather than in the
browser, so a page carries no highlighting script and renders identically with
JavaScript disabled. The emitted span classes are the website kit's own
``token-*`` classes, which is what keeps compiler sources, generated Ada, and
shell transcripts in one palette.

Highlighting is line-oriented and carries state between lines, because C++
block comments and Ada string continuations cross line boundaries and the diff
renderer needs to colour one line at a time.
"""

from __future__ import annotations

import html
import re
from dataclasses import dataclass


ADA_KEYWORDS = frozenset(
    """abort abs abstract accept access aliased all and array at begin body case constant
    declare delay delta digits do else elsif end entry exception exit for function generic
    goto if in interface is limited loop mod new not null of or others out overriding
    package parallel pragma private procedure protected raise range record rem renames
    requeue return reverse select separate some subtype synchronized tagged task terminate
    then type until use when while with xor""".split()
)

CPP_KEYWORDS = frozenset(
    """alignas alignof and and_eq asm auto bitand bitor break case catch class compl concept
    const consteval constexpr constinit const_cast continue co_await co_return co_yield
    decltype default delete do dynamic_cast else enum explicit export extern false for
    friend goto if inline mutable namespace new noexcept not not_eq nullptr operator or
    or_eq private protected public register reinterpret_cast requires return sizeof static
    static_assert static_cast struct switch template this thread_local throw true try
    typedef typeid typename union using virtual volatile while xor xor_eq""".split()
)

CPP_TYPES = frozenset(
    """bool char char8_t char16_t char32_t double float int long short signed unsigned void
    wchar_t size_t ssize_t ptrdiff_t nullptr_t int8_t int16_t int32_t int64_t uint8_t
    uint16_t uint32_t uint64_t intptr_t uintptr_t tree gimple rtx bitmap""".split()
)

SHELL_KEYWORDS = frozenset(
    """if then elif else fi for while until do done case esac function in select time
    break continue return exit local export readonly declare set shift trap unset""".split()
)

ADA_TOKEN = re.compile(
    r"""--[^\n]*
    |"(?:[^"]|"")*"
    |'(?:[^']|'')'
    |\b[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+\b
    |'[A-Za-z][A-Za-z0-9_]*
    |\b\d[\d_]*(?:\#[0-9A-Fa-f_.]+\#|\.\d[\d_]*)?(?:[Ee][+-]?\d[\d_]*)?\b
    |=>|:=|\.\.|<>|<=|>=|/=|\*\*
    |\b[A-Za-z][A-Za-z0-9_]*\b""",
    re.VERBOSE,
)

CPP_TOKEN = re.compile(
    r"""//[^\n]*
    |/\*
    |\*/
    |R"[^(]*\([\s\S]*?\)[^"]*"
    |"(?:\\.|[^"\\])*"
    |'(?:\\.|[^'\\])*'
    |\b(?:0[xXbB][0-9A-Fa-f']+|\d[\d']*(?:\.\d[\d']*)?(?:[eE][+-]?\d+)?)[uUlLfF]*\b
    |\b[A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z_][A-Za-z0-9_]*)+\b
    |\b[A-Za-z_][A-Za-z0-9_]*\b
    |->\*|\.\*|::|->|\+\+|--|<<=|>>=|<<|>>|<=|>=|==|!=|&&|\|\||[-+*/%&|^!~<>=?:]""",
    re.VERBOSE,
)

SHELL_TOKEN = re.compile(
    r"""\#[^\n]*
    |"(?:\\.|[^"\\])*"
    |'[^']*'
    |\$\{[A-Za-z_][A-Za-z0-9_]*\}|\$[A-Za-z_][A-Za-z0-9_]*|\$[@*#?$!0-9]
    |\b\d+\b
    |&&|\|\||>>|<<|[|&;<>]
    |\b[A-Za-z_][A-Za-z0-9_-]*\b""",
    re.VERBOSE,
)

LANGUAGES = {
    "ada": "ada",
    "adb": "ada",
    "ads": "ada",
    "c++": "cpp",
    "cpp": "cpp",
    "cc": "cpp",
    "c": "cpp",
    "h": "cpp",
    "sh": "shell",
    "bash": "shell",
    "shell": "shell",
    "console": "shell",
    "text": "text",
    "": "text",
}

#  Compiler sources and testsuite fixtures, keyed by the file suffix a patch or
#  a bundle test directory carries.
SUFFIXES = {
    ".adb": "ada",
    ".ads": "ada",
    ".ada": "ada",
    ".cc": "cpp",
    ".c": "cpp",
    ".C": "cpp",
    ".h": "cpp",
    ".hh": "cpp",
    ".sh": "shell",
}


@dataclass(frozen=True)
class State:
    """Highlighting state that survives a line break."""

    in_block_comment: bool = False


CLEAN = State()


def language_for_info(info: str) -> str:
    """Return the highlighter name for a Markdown fence info string."""
    return LANGUAGES.get(info.strip().lower(), "text")


def language_for_path(path: str) -> str:
    """Return the highlighter name for a repository file path."""
    for suffix, language in SUFFIXES.items():
        if path.endswith(suffix):
            return language
    return "text"


def highlight(language: str, code: str) -> str:
    """Return CODE as escaped HTML with token spans for LANGUAGE."""
    state = CLEAN
    rendered = []
    for line in code.split("\n"):
        markup, state = highlight_line(language, line, state)
        rendered.append(markup)
    return "\n".join(rendered)


def highlight_line(language: str, line: str, state: State = CLEAN) -> tuple[str, State]:
    """Return LINE highlighted for LANGUAGE and the state for the next line."""
    if language == "ada":
        return _tokenize(line, ADA_TOKEN, _ada_class), CLEAN
    if language == "cpp":
        return _cpp_line(line, state)
    if language == "shell":
        return _tokenize(line, SHELL_TOKEN, _shell_class), CLEAN
    return html.escape(line, quote=False), CLEAN


def _span(value: str, token_class: str) -> str:
    escaped = html.escape(value, quote=False)
    return f'<span class="{token_class}">{escaped}</span>' if token_class else escaped


def _tokenize(line: str, pattern: re.Pattern[str], classify) -> str:
    rendered = []
    position = 0
    for match in pattern.finditer(line):
        rendered.append(html.escape(line[position:match.start()], quote=False))
        token = match.group(0)
        rendered.append(_span(token, classify(token)))
        position = match.end()
    rendered.append(html.escape(line[position:], quote=False))
    return "".join(rendered)


def _ada_class(token: str) -> str:
    if token.startswith("--"):
        return "token-comment"
    if token.startswith('"') or re.fullmatch(r"'.*'", token):
        return "token-string"
    if token.startswith("'"):
        return "token-attribute"
    if token[0].isdigit():
        return "token-number"
    if "." in token:
        return "token-operator" if token == ".." else "token-type"
    if token.lower() in ADA_KEYWORDS:
        return "token-keyword"
    if token.lower() in {"true", "false"}:
        return "token-number"
    if token[0].isalpha():
        return ""
    return "token-operator"


def _shell_class(token: str) -> str:
    if token.startswith("#"):
        return "token-comment"
    if token[0] in "\"'":
        return "token-string"
    if token.startswith("$"):
        return "token-attribute"
    if token[0].isdigit():
        return "token-number"
    if token in SHELL_KEYWORDS:
        return "token-keyword"
    if token[0].isalpha() or token[0] == "_":
        return ""
    return "token-operator"


def _cpp_class(token: str) -> str:
    if token.startswith("//"):
        return "token-comment"
    if token[0] in "\"'" or token.startswith('R"'):
        return "token-string"
    if token[0].isdigit():
        return "token-number"
    if "::" in token:
        return "token-type"
    if token in CPP_KEYWORDS:
        return "token-keyword"
    if token in CPP_TYPES:
        return "token-type"
    if token[0].isalpha() or token[0] == "_":
        return ""
    return "token-operator"


def _cpp_line(line: str, state: State) -> tuple[str, State]:
    in_comment = state.in_block_comment
    rendered = []
    position = 0

    if in_comment:
        end = line.find("*/")
        if end == -1:
            return _span(line, "token-comment"), State(in_block_comment=True)
        rendered.append(_span(line[: end + 2], "token-comment"))
        position = end + 2
        in_comment = False

    directive = re.match(r"\s*#\s*[a-z_]+", line[position:])
    if directive and not in_comment:
        rendered.append(_span(directive.group(0), "token-keyword"))
        position += directive.end()

    while position < len(line):
        match = CPP_TOKEN.search(line, position)
        if not match:
            rendered.append(html.escape(line[position:], quote=False))
            break
        rendered.append(html.escape(line[position:match.start()], quote=False))
        token = match.group(0)
        if token == "/*":
            end = line.find("*/", match.end())
            if end == -1:
                rendered.append(_span(line[match.start():], "token-comment"))
                return "".join(rendered), State(in_block_comment=True)
            rendered.append(_span(line[match.start():end + 2], "token-comment"))
            position = end + 2
            continue
        rendered.append(_span(token, _cpp_class(token)))
        position = match.end()

    return "".join(rendered), State(in_block_comment=False)
