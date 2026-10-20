# Privatus Analytics – Google Tag Manager templates

A custom tag template for GTM web containers, used together with the tracking script:

| File | Tag | What it does |
| --- | --- | --- |
| `privatus-event.tpl` | **Privatus Analytics – Event** | Calls `privatus.track(name, props)` (name, properties table, revenue/currency). If pa.js hasn't loaded yet it pushes `['track', [name, props]]` onto `window.privatus.q`, which pa.js replays on load. |

## Loading the tracker (pageviews)

Privatus Analytics collects data only through its tracking script, `pa.js`, so there is no pageview template.
A sandboxed template cannot load pa.js: the script reads all of its configuration (`data-site`, `data-api`, …)
from `document.currentScript` attributes, and sandboxed template code cannot set attributes on a script it
injects. Load pa.js from a **Custom HTML** tag on *All Pages* instead (or paste the site snippet into your
pages). It counts pageviews, including single-page app navigations, by itself:

```html
<script>
  (function () {
    var s = document.createElement('script');
    s.defer = true;
    s.src = 'https://privatusanalytics.com/js/pa.js';
    s.setAttribute('data-site', 'pa_XXXX');
    // s.setAttribute('data-modules', 'engage,auto');
    document.head.appendChild(s);
  })();
</script>
```

## Install (import)

1. **Tags → New → Custom HTML**: paste the snippet above with your Site ID (`pa_…`). Trigger: *All Pages*.
2. GTM → **Templates → Tag Templates → New** → ⋮ menu → **Import** → choose `privatus-event.tpl` → **Save**.
3. **Tags → New → Privatus Analytics – Event**: event name, properties (key/value, where numeric strings become
   numbers and `true`/`false` become booleans), optional revenue (major units) + currency. Fire it on your
   conversion triggers. Events fired before pa.js loads are queued and replayed.
4. Preview, then Publish.

### Namespace

The Event template uses the global `privatus`. If pa.js runs with a custom `data-namespace`, change the namespace
field and the *Accesses global variables* permission to match.

## Permissions

* Event: `access_globals` (`privatus` read/write, `privatus.q` read/write/execute, `privatus.track` read/execute),
  `logging` (debug only).

No cookies are set or read, nothing is written to storage.

## Community Template Gallery

The Gallery requires a repository for the template with `template.tpl`, `metadata.yaml` and an Apache-2.0
`LICENSE` at the root. To publish: create the repo, copy the `.tpl` as `template.tpl`, copy
`metadata.yaml` (set `sha` to the commit containing the template) and `LICENSE-APACHE-2.0.txt` as `LICENSE`,
then submit via the Gallery. The template is therefore dual-licensed **MIT OR Apache-2.0**.
Add a brand thumbnail (`___INFO___.brand.thumbnail`, base64 PNG) before submitting.

## Tests

The `___TESTS___` sections run in GTM's template editor (**Tests → Run tests**). They also run offline with a
small harness that parses every section, checks the permissions against the APIs used (including global key
rights), and executes the same scenarios:

```sh
docker run --rm -v "$PWD":/w -w /w node:22 node test/run-tests.mjs
```
