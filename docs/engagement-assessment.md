# Engagement assessment

Free checks snapshot Topics Viewed (`topics_entered`), Posts Read
(`posts_read_count`), Reading Time (`time_read`, seconds), and Days Visited from
Discourse's user statistics. They are local context, never sent to Stop Forum Spam.
The snapshot and assessment are stored in the scan's existing policy JSON, so
later reading does not rewrite the explanation of a past decision.

These correlated metrics produce one adjustment, not three independent votes:

| Reading history at check time | Risk adjustment |
| --- | --- |
| Missing statistics | 0, unavailable |
| Zero reading on a new account | 0 |
| Zero reading after posting, or a later check at least one hour after signup | +10 |
| Any reading, below the following thresholds | -5 |
| At least 1 topic, 3 posts and 60 seconds | -10 |
| At least 5 topics, 30 posts, 600 seconds and 2 days visited | -15 |

These are configurable defaults. The four adjustments live in the plugin's admin
settings; reading rewards range from -100 to 0 and the no-reading adjustment from
0 to 100. Missing statistics and fresh-account neutrality remain fixed at zero.

Days visited corroborates repeat visits; it does not prove reading occurred on
each day. Time recorded by Discourse is a proxy for attention, not proof. Counters
can be gamed. Initial thresholds are heuristics requiring validation against actual
moderator outcomes; they are neither calibrated probabilities nor percentages.

External evidence adds weighted, capped email and IP report counts after recency;
see [external scoring](external-scoring.md). Posting and extension points share the
configured local cap. Reading adjusts that combined suspicion once, with a minimum
of zero. Confirmed spam is added afterwards and cannot be reduced by reading.
The final score is capped at 100.
Zero reading alone changes a clear assessment to “Some concern”; it never creates
a review or sanction. Reading reassurance below -5 converts a silence recommendation to review,
independently of configurable external score weights.
Strong external evidence always requires at least review, and weak external
evidence remains visible even if the score reaches zero. These evidence floors
mean points alone do not determine the outcome.

Missing or failed provider checks remain unknown and unscored regardless of
engagement. Staff, age, trust-level and exception exclusions remain in force.
Existing independent moderation is not undone when a later score improves.

The assessment also includes the [local signals](local-signals.md) contribution
to the displayed score. Those points can request review but cannot restore a
silence recommendation reduced by reading. Engagement is evaluated on registration,
delayed, manual and activity checks. There is no periodic sweep. Old scans
without an assessment retain their original presentation. Configurable basic
weights, this assessment and its explanation remain part of the free plugin.
Pro may later add trend analysis.
