# MUHADIR Invitations

This folder contains the standalone MUHADIR invitation pages for review, editing, and GitHub Pages deployment.

## Included Pages

- `invitation/` — the original invitation design, with a traditional project-introduction style and audience-specific invitation links.
- `invitation-pass/` — the dynamic QR/MUHADIR PASS design, with the scan flow `sync → success → reveal` and digital pass styling.

Both pages are standalone HTML/CSS/JavaScript experiences. No build step is required.

## Local Testing

From inside `muhadirapp/`, run:

```bat
py -m http.server 8000
```

Then open:

```text
http://localhost:8000/muhadir-invitations/invitation/?type=general
http://localhost:8000/muhadir-invitations/invitation/?type=doctor&title=د&name=محمد%20جبلي
http://localhost:8000/muhadir-invitations/invitation/?type=engineers44
http://localhost:8000/muhadir-invitations/invitation/?type=colleague&title=م&name=إيلاف%20الغامدي
```

And:

```text
http://localhost:8000/muhadir-invitations/invitation-pass/?type=general
http://localhost:8000/muhadir-invitations/invitation-pass/?type=doctor&title=د&name=محمد%20جبلي
http://localhost:8000/muhadir-invitations/invitation-pass/?type=engineers44
http://localhost:8000/muhadir-invitations/invitation-pass/?type=colleague&title=م&name=إيلاف%20الغامدي
http://localhost:8000/muhadir-invitations/invitation-pass/?type=family
http://localhost:8000/muhadir-invitations/invitation-pass/?type=unknown
```

## GitHub Pages

These pages are GitHub Pages-ready because each page uses local relative paths such as:

```text
styles.css
script.js
assets/images/muhadir-logo.jpg
```

Expected deployed paths:

```text
https://USERNAME.github.io/REPO_NAME/muhadir-invitations/invitation/
https://USERNAME.github.io/REPO_NAME/muhadir-invitations/invitation-pass/
```

Example parameterized link:

```text
https://USERNAME.github.io/REPO_NAME/muhadir-invitations/invitation-pass/?type=doctor&title=د&name=محمد%20جبلي
```

## Notes

- Keep the two designs separate; do not merge them into one folder.
- `invitation-pass/` keeps the approved wording: `تم تسجيلكم ضمن حضور مُحضِر`.
- Use `بوث` for Booth 31 wording.
