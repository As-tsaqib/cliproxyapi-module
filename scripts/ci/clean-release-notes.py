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

    print(changelog)

if __name__ == "__main__":
    main()
