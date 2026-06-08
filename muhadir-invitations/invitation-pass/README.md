# MUHADIR PASS

`invitation-pass/` contains a standalone QR-based invitation experience for MUHADIR.

The page uses MUHADIR project branding: the official logo, the dark teal/navy theme, Cairo typography, and the same soft cyan/gold accent direction used by the existing invitation and project overview pages.

The page presents a staged smart-attendance experience after scanning a QR/link:

1. **Sync** — animated scan/verification with cycling status text
2. **Success** — confirmation moment with animated checkmark
3. **Reveal** — digital pass with audience-specific copy, بوث 31, and event details

It confirms preliminary attendance for the MUHADIR experience and directs the recipient to بوث 31.

## Open

Open directly in a browser:

```text
invitation-pass/index.html
```

No build step is required.

The page uses Google Fonts for Cairo typography, with local system fallbacks if the font fails to load.

## Branding

- Logo file: `invitation-pass/assets/images/muhadir-logo.jpg`
- Theme source: colors are aligned with `invitation/styles.css` and `muhadirapp/docs/project-overview-dynamic/styles.css`
- Font: `Cairo`, loaded from Google Fonts, with `Segoe UI` and system fallbacks

To adjust the visual theme, edit the CSS variables at the top of:

```text
invitation-pass/styles.css
```

The QR helper uses the same local logo and related theme variables in:

```text
invitation-pass/qr-links.css
```

## Supported Links

General:

```text
invitation-pass/index.html?type=general
```

Doctor:

```text
invitation-pass/index.html?type=doctor&title=د&name=محمد%20جبلي
```

Engineers Batch 44:

```text
invitation-pass/index.html?type=engineers44
```

Major colleague:

```text
invitation-pass/index.html?type=colleague&title=م&name=إيلاف%20الغامدي
```

Family:

```text
invitation-pass/index.html?type=family
```

Unknown `type` values fall back to `general`.

## Link & QR Generator

Local helper to build encoded invitation URLs and QR codes:

```text
invitation-pass/qr-links.html
```

Uses the `qrcodejs` library from jsDelivr CDN for QR rendering. The main pass page is not modified by this tool.

## Edit Event Values

Event values are defined in `script.js`:

```js
const invitationConfig = {
  eventName: "معرض إنجاز 2026",
  context: "مشاريع التخرج بكلية الحاسبات – ضمن ملتقى المهنة والابتكار 2026",
  booth: "31",
  time: "من 11 صباحًا إلى 2 ظهرًا",
  date: "الثلاثاء 9 يونيو 2026م",
  location: "بهو قاعة الملك عبدالعزيز – المدينة الجامعية بالعابدية",
};
```

Audience-specific text is also in `script.js` under `audienceCopy`.

## Review Media

Screenshots are saved in:

```text
invitation-pass/assets/screenshots/
```

Requested screenshot files:

```text
desktop.png
mobile.png
doctor.png
colleague.png
engineers44.png
family.png
```

Optional recordings can be saved in:

```text
invitation-pass/assets/recordings/
```
