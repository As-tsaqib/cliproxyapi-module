#!/usr/bin/env python3
import sys
import re

def main():
    body = sys.stdin.read()
    if not body:
        return

    # Find Changelog or What's Changed section
    pos = re.search(r"#*\s*(Changelog|What['’]s\s+Changed)", body, re.IGNORECASE)
    if pos:
        changelog = body[pos.start():].strip()
    else:
        # Strip asset boilerplate sections if no Changelog header
        changelog = re.sub(
            r"#*\s*(Linux|FreeBSD|macOS|Windows)\s+release\s+assets.*?(?=\n#|\Z)",
            "",
            body,
            flags=re.DOTALL | re.IGNORECASE,
        ).strip()

    # Remove top '## Changelog' header to prevent duplicated header inside KernelSU dialog
    changelog = re.sub(
        r"^#*\s*(Changelog|What['’]s\s+Changed)\s*\n+",
        "",
        changelog,
        flags=re.IGNORECASE,
    ).strip()

    # Format Full Changelog URL into an explicit clean clickable Markdown link: [Full Changelog](URL)
    def link_repl(m):
        url = m.group(2)
        return f"[Full Changelog]({url})"

    changelog = re.sub(
        r"(\*?\*?Full Changelog\*?\*?:?\s*)(https://[^\s\)]+)",
        link_repl,
        changelog,
        flags=re.IGNORECASE,
    )

    print(changelog)

if __name__ == "__main__":
    main()
