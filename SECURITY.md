# Security policy

## Reporting a vulnerability

Please report security problems privately, not in a public issue. Open the repo's **Security** tab and choose **Report a vulnerability**, or go straight to https://github.com/stuloh/finder-menu-lite/security/advisories/new.

Include what you found, how to reproduce it, and your macOS version. I'll reply as soon as I can.

## What's in scope

- The helper app's handling of `findermenu://` links (`Sources/FinderMenu/main.swift`)
- The Finder extension (`Sources/FinderMenuExtension`)
- The file conversions: Convert to PDF's AppleScript, and the image handling in `Sources/FinderMenu/Images.swift`
- `install.sh` and `uninstall.sh`

Especially anything that lets another app or a website make Finder Menu do something you didn't ask for.

## Supported versions

Only the latest version on `main` gets fixes. To update, run this in the repo folder:

```bash
git pull && ./install.sh
```

This is a fork of [Finder Menu](https://github.com/nikgrbn/finder-menu). If a problem is also in the original project's code, please report it there too.
