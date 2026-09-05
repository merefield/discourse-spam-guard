# Settings implementation status

All 21 settings in the free plugin's `config/settings.yml` have runtime consumers.

| Setting (all prefixed `spam_guard_`) | Implemented behavior |
| --- | --- |
| `enabled` | Gates scheduling, checking and enforcement; recovery remains available |
| `mode` | Observe records, Review creates review cases, Protect also permits qualified external-evidence silencing |
| `preset` | Conservative requires strong email and IP; balanced permits strong email alone |
| `check_email`, `check_ip`, `check_username` | Select identifiers sent to the provider |
| `local_signals` | Gates local evidence and activity-triggered checks |
| `reading_limited_adjustment` | Limited reading adjustment, default -5 |
| `reading_meaningful_adjustment` | Meaningful reading adjustment, default -10 |
| `reading_sustained_adjustment` | Sustained reading adjustment, default -15 |
| `no_reading_adjustment` | Eligible no-reading adjustment, default +10 |
| `confirmed_spam_points` | Points per distinct confirmed spam post, default 80 |
| `local_points_cap` | Combined local contribution cap after reading, default 100 |
| `region` | Selects the provider endpoint |
| `recheck_hours` | Schedules the registration follow-up delay; zero prevents new follow-up scheduling |
| `retention_days` | Controls daily scan cleanup, preserving pending review evidence |
| `email_confidence`, `email_frequency` | Thresholds for strong email evidence |
| `ip_confidence`, `ip_frequency` | Thresholds for strong IP evidence |
| `max_evidence_age_days` | Limits report age for strong external evidence |

Settings changes affect subsequent checks, not stored assessments. Changing the
follow-up delay does not reschedule or cancel jobs already queued. Enabling the
plugin does not backfill existing accounts. Recheck an account to apply new weights.
Weights are saved with each assessment. Detection thresholds and the duplicate/burst
weights remain constants documented in [local signals](local-signals.md).
When no enabled identifier is available, the check is skipped and remains unscored;
local signals can still request review when their review threshold is met. The
same applies during provider outages. Neither case invents an external result or
permits automatic silencing.

The Pro extension's `spam_guard_pro_enabled` setting belongs to a development
scaffold. No Pro workflows consume it yet; enabling it adds no functionality.

Policy version 5 verification: 125 backend/system examples and 22 browser tests
pass. Coverage includes saving a weight through the admin settings UI, preserving
historical snapshots, per-post multiplication before the cap, and a real
`PostCreator` check of duplicate prevention and later repetition after expiry.
