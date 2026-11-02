# Metrics

One row per date, written by `scripts/metrics.sh`. Aggregate counts only.

- stars, forks: totals on the date.
- clones_14d, unique_cloners_14d, views_14d, unique_visitors_14d: GitHub's rolling 14-day totals on the date. Rows overlap, so do not sum them across rows. Unique counts are per window, so they cannot be added or de-duplicated either.
- plugin_installs, skills_sh_installs: entered by hand. Neither Claude Code plugin marketplaces nor skills.sh documents an install-count API.
- site_visits: entered by hand. The website is not live.
- `-` means not recorded. It is not zero.

| date | stars | forks | clones_14d | unique_cloners_14d | views_14d | unique_visitors_14d | plugin_installs | skills_sh_installs | site_visits |
|---|---|---|---|---|---|---|---|---|---|
| 2026-11-02 | 0 | 0 | 55 | 37 | 0 | 0 | - | - | - |
