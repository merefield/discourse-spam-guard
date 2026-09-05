# Discourse Spam Guard

## Permissions

Persistent account exemptions are admin-only, including review-queue actions.
Moderators can view review evidence, silence accounts under their normal
permissions, and confirm existing restrictions. The plugin's admin dashboards,
settings and API endpoints remain admin-only.

## Required core integration

This development version requires the accompanying core changes in this checkout:
`admin_user_list_preloaded` and `reviewables_preloaded` events, plus the
`admin-user-list-column-count` frontend transformer. Deploy those core changes
alongside the plugin; these extension points are not yet assumed to exist in
upstream Discourse. No new database migration is required for this integration fix.

The integration audit and its resolution are recorded in
[core integration audit](docs/core-integration-audit.md).

Stop Forum Spam reputation checks and review tools for Discourse.

## Current implementation

- Background checks for new registrations and an optional delayed recheck.
- Observe, review and protect modes; observe is the default.
- Email and public registration IP checks, with optional username evidence.
- Evidence evaluated by frequency, reputation score and recency. Username-only
  and weak or stale evidence never automatically silence an account.
- Reading engagement contributes a capped risk adjustment, with an explanation
  and a snapshot of the metrics. See [engagement assessment](docs/engagement-assessment.md).
- Exact duplicate posts, posting bursts across public topics and staff-confirmed
  spam history contribute capped local signals. Eligible accounts receive a
  background check after posting or a flag review; local signals never authorize
  silencing. See [thresholds and exclusions](docs/local-signals.md).
- Review queue with explicit allow and silence actions. Allowing an account
  exempts it from future checks and only reverses a silence still owned by this plugin.
- Admin activity page, connection test and manual account checks. Manual checks
  never automatically silence an account.
- A dedicated Spam Guard column shows compact, coloured score boxes and exemptions.
  Each box links to the account with its Spam Guard dashboard open. Missing scores
  are grey and labelled N/A; a calculated zero remains 0%.
  Summary data is batch loaded; browsing users never calls the provider. This
  uses the `admin-users-list-thead-after` and `admin-users-list-td-after` outlets
  and the `admin_user_list` serializer extension,
  with an `AdminUserIndexQuery` prepend to batch load the page's saved results.
- Exceptions remain manageable while automatic checks are disabled.
- HTTPS, bounded requests, hashed cache keys, provider concurrency limiting,
  bounded retries and an outage circuit breaker.
- Redacted scan history with configurable retention. Pending review evidence is
  retained until resolved. Account deletion and anonymization remove plugin records.

This is an initial development implementation, not a published release. The Pro
extension currently establishes the dependency boundary; its additional workflows
are not implemented yet. External spam reporting is also not implemented.

## Local installation

The development repositories live at `~/code/discourse-spam-guard` and
`~/code/discourse-spam-guard-pro-ext`, symlinked into `~/discourse/plugins`.
Run the Discourse database migrations and restart Rails and Sidekiq after installing.
The scan lookup optimization adds a concurrent index migration for existing installs.

Open Admin → Plugins → Spam Guard. Enable Spam Guard and start in observe mode.
Review the activity before choosing review or protect. The conservative preset
requires strong, recent email and IP evidence before an automatic silence; the
balanced preset permits strong, recent email evidence alone. IP-only evidence
can request review but never automatically silences an account.

Checks are asynchronous and cannot guarantee stopping a first post. Existing
Discourse rate limits, review rules and moderation tools still apply. Provider
unavailability never authorizes a restriction. Automatic checks exclude staff,
accounts older than seven days, trust levels above one and explicit exceptions.
Manual lookups can examine older ordinary accounts.

## Data and recovery

Enabled email, registration IP and username checks send those identifiers to Stop
Forum Spam. Disable identifiers your site should not transmit. Scan records store
normalized evidence rather than raw identifiers; cache keys hash the lookup inputs.
The provider's own data handling is separate from this plugin's local retention.

Use “Allow this account” from its review or admin account controls to grant an
exception. Removing an exception does not immediately reenforce an old decision.
Independent staff silences and suspensions are preserved. Historical action labels
describe the action at the time of a scan, not the account's current restriction.

## Development

GitHub Actions uses Discourse's standard reusable plugin workflow on pull requests
and pushes to `main`. It runs lint, backend, frontend, system and model annotation
checks against upstream Discourse's `latest` branch. The free plugin's tests do
not require the Pro extension. CI does not apply the local core changes listed
above; integration checks may fail until those hooks are available upstream.

Backend tests: `LOAD_PLUGINS=1 bin/rspec plugins/discourse-spam-guard/spec`.
Browser tests: `bin/qunit --standalone --target discourse-spam-guard`.

This development checkout contains unrelated plugins with a conflicting
`mime-types-data` dependency. Filtered local test bootstraps in `/tmp` were used
to load only the two Spam Guard plugins. `bin/qunit` currently overwrites the
`LOAD_PLUGINS` environment variable, so a temporary wrapper preserves the filter.
These wrappers do not modify Discourse core and are not required on a clean checkout.

See [status design](docs/status-design.md) for evidence colours, accessible labels
and the distinction between evidence and actions.
