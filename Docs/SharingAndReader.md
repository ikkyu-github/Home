# Sharing + Reader (Lightweight)

This project implements Safari-like sharing and a lightweight, reversible “reader-ish” mode.

## Sharing

### Share link (current page)
- Uses the active tab model (active tab only) to resolve the current URL.
- Presents `UIActivityViewController` with the URL.

### Share as PDF (current page)
- Generates a PDF **asynchronously** from the active tab’s `WKWebView`.
- The PDF is written to a **temporary** file under the system temp directory.
- The temp PDF is **deleted** when the share sheet dismisses.
- If the user switches tabs while PDF generation is running, the share is aborted and the temp file is deleted.

### Share downloaded file
- Download items can be shared from the Downloads UI via a context menu.
- Sharing is done with a file URL (no additional persistence is introduced).

### Private-mode discipline
- Sharing does not persist history.
- PDFs generated for sharing are always temporary and best-effort deleted on dismiss.

## Reader mode (lightweight)

Reader mode is intentionally **CSS-only**:
- No content extraction.
- No DOM rewrite or overlay injection.
- No long-lived observers or timers.

Implementation details:
- A single style tag is injected/updated.
- A single class on `<html>` toggles the mode.
- Optional clutter-hiding heuristics are applied via CSS selectors (`nav`, `header`, `footer`, `aside`).

Reader availability is a lightweight heuristic based on:
- Minimum text length/word count.
- Minimum paragraph count.
- Presence of `article`/`main` (preferred, but falls back to `body`).

## Manual checklist

- Share button shares the active tab’s URL.
- “Share as PDF” generates a PDF and cleans up the temp file after dismiss.
- Switching tabs during PDF generation does not share the wrong tab.
- Downloads list supports “Share…” on an item.
- Reader toggle is reversible, and the page returns to normal styling on disable.
