# Metrics

One row per date, written by `scripts/metrics.sh`. Aggregate counts only.

- stars, forks: totals on the date.
- clones_14d, unique_cloners_14d, views_14d, unique_visitors_14d: GitHub's rolling 14-day totals on the date. Rows overlap, so do not sum them across rows. Unique counts are per window, so they cannot be added or de-duplicated either.
- Run the script at least every 14 days. GitHub keeps only 14 days of traffic, so a longer gap loses traffic for good.
- plugin_installs: entered by hand. Claude Code plugin marketplaces document no install-count API.
- skills_sh_installs: entered by hand. skills.sh documents an install-count API (https://www.skills.sh/docs/api), but it needs a Vercel OIDC token that a local maintainer script does not have.
- site_visits: entered by hand. The website is not live.
- `-` means not recorded. It is not zero.

Maintainer test installs inflate the clone counts in rows until about 2026-11-16.

| date | stars | forks | clones_14d | unique_cloners_14d | views_14d | unique_visitors_14d | plugin_installs | skills_sh_installs | site_visits |
|---|---|---|---|---|---|---|---|---|---|
| 2026-11-02 | 0 | 0 | 55 | 37 | 0 | 0 | - | - | - |
