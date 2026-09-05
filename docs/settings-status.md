# Settings implementation status

All 15 settings in the free plugin's `config/settings.yml` have runtime consumers.

| Setting (all prefixed `spam_guard_`) | Implemented behavior |
| --- | --- |
| `enabled` | Gates scheduling, checking and enforcement; recovery remains available |
| `mode` | Observe records, Review creates review cases, Protect also permits qualified external-evidence silencing |
| `preset` | Conservative requires strong email and IP; balanced permits strong email alone |
| `check_email`, `check_ip`, `check_username` | Select identifiers sent to the provider |
| `local_signals` | Gates local evidence and activity-triggered checks |
| `region` | Selects the provider endpoint |
| `recheck_hours` | Schedules the registration follow-up delay; zero prevents new follow-up scheduling |
| `retention_days` | Controls daily scan cleanup, preserving pending review evidence |
| `email_confidence`, `email_frequency` | Thresholds for strong email evidence |
| `ip_confidence`, `ip_frequency` | Thresholds for strong IP evidence |
| `max_evidence_age_days` | Limits report age for strong external evidence |

Settings changes affect subsequent checks, not stored assessments. Changing the
follow-up delay does not reschedule or cancel jobs already queued. Enabling the
plugin does not backfill existing accounts. Local thresholds and caps are constants
documented in [local signals](local-signals.md), not individual admin settings.
When no enabled identifier is available, the check is skipped and remains unscored;
local signals can still request review when their review threshold is met. The
same applies during provider outages. Neither case invents an external result or
permits automatic silencing.

The Pro extension's `spam_guard_pro_enabled` setting belongs to a development
scaffold. No Pro workflows consume it yet; enabling it adds no functionality.
