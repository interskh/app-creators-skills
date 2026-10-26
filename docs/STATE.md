# State file

The normative source is `docs/specs/2026-10-26-skill-conventions-design.md`
(§4.1, with §3.6). This file is the readable copy. If the two disagree,
the spec wins.

The file lives at `.app-creators/state.md` in the creator's project.
YAML frontmatter is the contract; markdown below it is free notes.
Skills read and update the frontmatter only. Recommend committing it;
it holds no secrets.

## Schema

```yaml
---
schema: "1.0"                  # major.minor, see evolution rules
updated: 2026-10-26
app:
  name: ""                     # display name
  slug: ""                     # kebab-case
  description: ""              # one sentence, used by store-listing
  languages: [en]              # content locales
framework:
  kind: expo | flutter | xcode | kotlin | nextjs | vite | static | unknown
  package_manager: npm | pnpm | yarn | bun | none
  evidence: ""                 # file that decided it, e.g. app.json
targets:                       # per destination: what the creator wants, what the project shows, what the store says
  web:
    intent: wanted | not-wanted | undecided
    detected: "yes" | "no"       # project carries config for this destination
    status: unknown | none | ready | live
    url: ""
    provider: vercel | cloudflare-pages | ""
    domain: ""
  ios:
    intent: wanted | not-wanted | undecided
    detected: "yes" | "no"
    status: unknown | none | ready | testflight | review | live
    bundle_id: ""
    asc_app_id: ""
  android:
    intent: wanted | not-wanted | undecided
    detected: "yes" | "no"
    status: unknown | none | ready | testing | review | live
    package: ""
readiness:                     # written by publish-readiness; a pass is bound to a revision
  web: { result: pass | fail | unknown, revision: "", date: "" }
  ios: { result: pass | fail | unknown, revision: "", date: "" }
  android: { result: pass | fail | unknown, revision: "", date: "" }
accounts:                      # presence only, never credentials; strings, never YAML booleans
  apple_developer: has | missing | pending
  google_play: has | missing | pending
  vercel: has | missing
tools:                         # chosen defaults, set by the skill that chose them
  deploy: ""
  analytics: ""
  iap: ""
  ads: ""
  payments: ""
  attribution: ""
monetization:
  model: none | paid | freemium | subscription | ads | hybrid
goal: publish | acquire | monetize | ""
history:                       # append-only, newest last
  - { skill: app-creators, version: "0.1.0", date: 2026-10-26, result: ok }
---
```

Creator-given facts with no field above go in the `provided:` map,
keyed by the skill that asks:

```yaml
provided:                      # creator-given facts with no field above, keyed by skill
  publish-readiness:
    privacy_policy_url: ""
    support_email_env: ""      # env var name, never the value
```

## Who creates it

Only `app-creators` creates the file, and only it migrates the file
across a schema major. Every other skill that finds the file missing
runs `app-creators` first and comes back.

## Unknown values

Unknown is written as `""` or `unknown`, never omitted. A skill that
needs a field another skill sets names that skill in its
`## Before you start` section.

## Schema evolution

`schema` is `major.minor`. Adding a field bumps minor; a rename, type
change, or change of meaning bumps major. A reader on the same major
treats a missing field as unknown. A reader on a different major stops
and asks the creator to run `app-creators`, which migrates the file.
That keeps "not detected", "older compatible state", and "incompatible
state" distinguishable.

## Readiness validity

A readiness `pass` is bound to the project revision it assessed. A
skill that reads a `pass` whose revision is not the current one treats
it as `unknown` in its own reasoning, never in the file.

## Ownership

Every field belongs to one class, and the class decides who may
overwrite it.

- **Detected facts** (`framework`, `app.slug`, `app.languages`,
  `targets.*.detected`): a cache of what the project shows. Any skill
  re-detects them when cheap and overwrites on evidence, recording the
  evidence. When state and project conflict, trust the project.
- **Provided facts** (`accounts`, `tools`, `monetization`, `goal`,
  `targets.*.intent`, `app.name`, `app.description`, and `provided:`):
  given by the creator once. No skill overwrites one without asking
  the creator; detection never does.
- **Recorded outcomes** (`targets.*.status`, `targets.*.url`,
  `targets.*.domain`, `targets.*.provider`, `targets.*.bundle_id`,
  `targets.*.package`, `targets.*.asc_app_id`, `readiness.*`):
  established by an external system or a dedicated assessment. Written
  only by the skill that performed or confirmed the action; never
  inferred from local files. `targets.*.status` starts as `unknown`;
  `none` is written only after a skill confirmed with the external
  system that nothing exists there. On a conflict, the external system
  wins and the skill rewrites the record. `readiness.*` is written only
  by `publish-readiness`; every other skill only reads it.

## Routing intent

Routing intent lives in `targets.*.intent`, set by `app-creators` from
the creator's answer. Later skills act on wanted destinations and never
reconstruct or re-ask which ones the creator meant.

## Write discipline

A skill reads the whole frontmatter, changes only the fields its
`## Update state` section lists, appends to `history`, and writes the
whole frontmatter back in one write. Fields it does not own and keys
it does not recognize (from a newer minor) are preserved verbatim.
`history` is never edited or truncated. One agent session per project
at a time is assumed; a half-written file is the only corruption mode,
and the previous value is recoverable from git.

## Migration direction

`app-creators` upgrades state from an older major by carrying every
provided fact, recorded outcome, and history row forward under the new
names, and re-detecting only detected facts. On a newer major than it
knows, it stops and tells the creator to update the plugin. State is
never downgraded.

## Field notes

Intent mapping, used for every `targets.*.intent`: a destination the
creator names is `wanted`; one they decline is `not-wanted`; one not
mentioned is `undecided`.

| field | class | allowed values | set by | note |
|---|---|---|---|---|
| `schema` | meta | `"<major>.<minor>"` | `app-creators` | Quoted string. A different major stops every other skill. |
| `updated` | meta | date `YYYY-MM-DD` | the skill that writes the file | Date of the last write. |
| `app.name` | provided | string | `app-creators` (asked once) | Display name. |
| `app.slug` | detected | kebab-case string | `app-creators` | Used as the project name by `publish-web`. |
| `app.description` | provided | string | `app-creators` (asked once) | One sentence; used by store-listing. |
| `app.languages` | detected | list of locales | `app-creators` | Content locales. |
| `framework.kind` | detected | `expo`, `flutter`, `xcode`, `kotlin`, `nextjs`, `vite`, `static`, `unknown` | `app-creators` | Xcode projects are `xcode`. |
| `framework.package_manager` | detected | `npm`, `pnpm`, `yarn`, `bun`, `none` | `app-creators` | |
| `framework.evidence` | detected | file path | `app-creators` | The file that decided `framework.kind`, e.g. `app.json`. |
| `targets.*.intent` | provided | `wanted`, `not-wanted`, `undecided` | `app-creators` | See the intent mapping above. |
| `targets.*.detected` | detected | `"yes"`, `"no"` | `app-creators` | YAML string, never a boolean. `"yes"` means the project carries config for this destination. |
| `targets.web.status` | recorded | `unknown`, `none`, `ready`, `live` | the skill that performed the action (`publish-web` today) | `unknown` on first run. |
| `targets.ios.status` | recorded | `unknown`, `none`, `ready`, `testflight`, `review`, `live` | the skill that performed the action | `unknown` on first run. |
| `targets.android.status` | recorded | `unknown`, `none`, `ready`, `testing`, `review`, `live` | the skill that performed the action | `unknown` on first run. |
| `targets.web.url` | recorded | URL or `""` | the skill that performed the action (`publish-web` today) | Live HTTPS URL. |
| `targets.web.provider` | recorded | `vercel`, `cloudflare-pages`, `""` | the skill that performed the action (`publish-web` today) | |
| `targets.web.domain` | recorded | domain or `""` | the skill that performed the action (`publish-web` today) | `""` when no custom domain. |
| `targets.ios.bundle_id` | recorded | string | the skill that performed the action | |
| `targets.ios.asc_app_id` | recorded | string | the skill that performed the action | App Store Connect app ID. |
| `targets.android.package` | recorded | string | the skill that performed the action | |
| `readiness.*.result` | recorded | `pass`, `fail`, `unknown` | `publish-readiness` | Stays `unknown` until `publish-readiness` ships; skills proceed under the gate's `unknown` rule. |
| `readiness.*.revision` | recorded | revision or `""` | `publish-readiness` | The revision a `pass` is bound to. |
| `readiness.*.date` | recorded | date or `""` | `publish-readiness` | |
| `accounts.apple_developer` | provided | `has`, `missing`, `pending`, `""` | the skill that asks | Presence only; string, never a boolean. `""` until the skill that asks has asked (first-run value written by `app-creators`). |
| `accounts.google_play` | provided | `has`, `missing`, `pending`, `""` | the skill that asks | Presence only; string, never a boolean. `""` until the skill that asks has asked (first-run value written by `app-creators`). |
| `accounts.vercel` | provided | `has`, `missing`, `""` | the skill that asks (`publish-web` today) | Presence only; string, never a boolean. `""` until the skill that asks has asked (first-run value written by `app-creators`). |
| `tools.*` | provided | tool name or `""` | the skill that chose it | `tools.deploy` is set by `publish-web` today. |
| `monetization.model` | provided | `none`, `paid`, `freemium`, `subscription`, `ads`, `hybrid`, `""` | the skill that asks | `""` until the skill that asks has asked (first-run value written by `app-creators`). |
| `goal` | provided | `publish`, `acquire`, `monetize`, `""` | `app-creators` (asked once) | |
| `provided.<skill>.*` | provided | string | the skill that asks | Never a secret; reference env var names only. |
| `history` | meta | list of `{ skill, version, date, result }` | every skill that writes | Append-only, newest last; never edited or truncated. |
