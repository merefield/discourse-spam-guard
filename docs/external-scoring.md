# External evidence scoring

Policy version 6 separates the external risk score from automatic-action eligibility.
These are rule-based weights, not calibrated probabilities. All settings below have
the `spam_guard_` prefix and are available in the free plugin's admin settings.

| Evidence | Default points | Weight setting |
| --- | --- | --- |
| Weak, stale, undated or informational match | 20 | `external_weak_points` |
| Moderate email | 50 | `email_moderate_points` |
| Strong email | 85 | `email_strong_points` |
| Moderate registration IP | 30 | `ip_moderate_points` |
| Strong registration IP | 50 | `ip_strong_points` |
| Both email and IP strong | 90 | `external_combined_points` |

Moderate email requires at least 3 reports and reputation 50; moderate IP requires
at least 5 reports and reputation 50. Configure these through
`email_moderate_frequency`, `email_moderate_confidence`, `ip_moderate_frequency`
and `ip_moderate_confidence`. Both count and reputation must qualify. Evidence
must have a valid last-report time within `max_evidence_age_days` (default 30),
not in the future, and must not be a provider blacklist-only result. Missing
reputation cannot qualify even when the configured threshold is zero.

Existing strong thresholds remain unchanged: email requires at least 5 reports
and reputation 90; IP requires at least 10 reports and reputation 95. Strong
matches also qualify for their moderate weight. The highest applicable weight
wins within an identifier and across identifiers; points are never summed across
email and IP. The combined weight is another candidate only when both are strong.
This avoids double-counting reports that may describe the same incident and
prevents stronger evidence reducing the score if an admin reverses the weights.
No match contributes zero, regardless of configured weights.

Moderate email requests review; moderate IP and username evidence alone remain
watch-only. Strong IP requests review. Automatic silencing still requires the
existing strong-evidence preset, Protect mode, an eligible automatic check and
no reading adjustment below -5. Changing point weights cannot grant automatic
silencing or remove evidence-based review. A high score alone does not authorize
a sanction. Manual checks never automatically silence.

The external score is added to the existing capped local contribution (including
one reading adjustment), then capped at 0–100. For nine email reports at reputation
66.67 last reported 21 hours ago, plus two weak IP reports and eligible zero
reading, the result is max(50, 20) + 10 = 60, with a review recommendation.
Observe mode still records the result without taking action.

Each new scan stores the weight and threshold snapshot, identifier tiers and
contributions. Historical scans retain their saved scores and presentation.
Rerun a manual check to use the new defaults; deployment does not rewrite old scans
or automatically recheck all existing users.

## Calibration around the display bands

A score of 0 is green; 1–30 is yellow (Suspicious); 31–69 is amber (Moderate
concern); 70–100 is red (High concern). These bands describe the numeric score,
not the action recommendation. Exemptions remain blue, unavailable scores grey.

Strong email and a staff-confirmed spam post each default to 85 points. Subtracting
the strongest default reading reassurance of 15 still leaves 70, in the red band.
Both strong external identifiers default to 90, leaving 75 after that reassurance.
Two confirmed posts still reach 100 by multiplication and the normal final cap.
Custom reading weights and score weights can move these results between bands.
Changing a default does not overwrite an administrator's explicit saved setting.
