import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { notEq } from "discourse/truth-helpers";
import DRelativeDate from "discourse/ui-kit/d-relative-date";
import dFormatDuration from "discourse/ui-kit/helpers/d-format-duration";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";
import SpamGuardCalculation from "./spam-guard-calculation";
import SpamGuardRiskScore from "./spam-guard-risk-score";
import SpamGuardStatus from "./spam-guard-status";

const suppliedValue = (value) =>
  value ?? i18n("spam_guard.dashboard.not_supplied");

export default class SpamGuardEvidence extends Component {
  get hasScore() {
    const assessment = this.args.scan?.policy?.assessment;
    return (
      this.args.scan?.status === "checked" &&
      assessment?.scored &&
      Number.isFinite(assessment.score) &&
      assessment.score >= 0 &&
      assessment.score <= 100
    );
  }

  get summary() {
    if (!this.hasScore) {
      return i18n("spam_guard.dashboard.unscored_help");
    }
    const calculation = this.args.scan.policy.assessment.calculation;
    if (!calculation) {
      return i18n("spam_guard.calculation.legacy_summary");
    }
    if (calculation.confirmed > 0) {
      return i18n("spam_guard.calculation.confirmed_summary", {
        suspicion: calculation.suspicion,
        confirmed: calculation.confirmed,
      });
    }
    const points = this.args.scan.policy.assessment.external_scoring.points;
    return i18n("spam_guard.calculation.summary", {
      email: points.email,
      ip: points.ip,
      adjustment: calculation.suspicion - calculation.external,
    });
  }

  <template>
    <div class="spam-guard-evidence" ...attributes>
      {{#if @scan}}
        <header class="spam-guard-evidence__header">
          <SpamGuardRiskScore
            @exempt={{@exempt}}
            @score={{@scan.policy.assessment.score}}
            @scored={{@scan.policy.assessment.scored}}
            @decision={{@scan.decision}}
            @status={{@scan.status}}
          />
          <div class="spam-guard-evidence__overview">
            <h3 class="spam-guard-evidence__title">{{#if @scan.username}}{{i18n
                  "spam_guard.dashboard.account"
                  username=@scan.username
                }}{{else}}{{i18n "spam_guard.dashboard.assessment"}}{{/if}}</h3>
            <p class="spam-guard-evidence__summary">{{this.summary}}</p>
            <dl class="spam-guard-evidence__facts">
              <div><dt>{{i18n "spam_guard.action"}}</dt><dd>{{i18n
                    (concat "spam_guard.actions." @scan.action_taken)
                  }}</dd></div>
              <div><dt>{{i18n "spam_guard.dashboard.checked"}}</dt><dd
                ><DRelativeDate @date={{@scan.created_at}} /></dd></div>
              {{#if @scan.source}}<div><dt>{{i18n
                      "spam_guard.dashboard.source"
                    }}</dt><dd>{{i18n
                      (concat "spam_guard.dashboard.sources." @scan.source)
                    }}</dd></div>{{/if}}
            </dl>
            {{#if @scan.error_code}}<p
                class="spam-guard-evidence__notice"
              >{{i18n
                  (concat "spam_guard.errors." @scan.error_code)
                }}</p>{{/if}}
          </div>
        </header>

        <div class="spam-guard-evidence__layout">
          <SpamGuardCalculation @scan={{@scan}} />
          <div class="spam-guard-evidence__body">
            <section class="spam-guard-evidence__provider">
              <div class="spam-guard-evidence__section-header">
                <h3 class="spam-guard-evidence__heading">{{i18n
                    "spam_guard.dashboard.provider"
                  }}</h3>
                {{#if @scan.policy.assessment}}
                  {{#if
                    (notEq
                      @scan.decision @scan.policy.assessment.external_decision
                    )
                  }}
                    <SpamGuardStatus
                      @decision={{@scan.policy.assessment.external_decision}}
                      @status={{@scan.status}}
                    />
                  {{/if}}
                {{/if}}
              </div>
              <div class="spam-guard-evidence__signals">
                {{#each @scan.evidence as |item|}}
                  <div class="spam-guard-evidence__signal">
                    <strong>{{i18n
                        (concat "spam_guard.fields." item.field)
                      }}</strong>
                    <span class="spam-guard-evidence__report-count">{{i18n
                        "spam_guard.reports"
                        count=item.frequency
                      }}</span>
                    {{#if item.appears}}
                      <dl class="spam-guard-evidence__signal-details">
                        <div><dt>{{i18n
                              "spam_guard.dashboard.confidence"
                            }}</dt><dd>{{suppliedValue
                              item.confidence
                            }}</dd></div>
                        <div><dt>{{i18n
                              "spam_guard.dashboard.last_report"
                            }}</dt><dd>{{#if item.last_seen}}<DRelativeDate
                                @date={{item.last_seen}}
                              />{{else}}{{i18n
                                "spam_guard.dashboard.not_supplied"
                              }}{{/if}}</dd></div>
                      </dl>
                    {{/if}}
                  </div>
                {{else}}
                  <p class="spam-guard-evidence__caption">{{i18n
                      "spam_guard.dashboard.no_provider_evidence"
                    }}</p>
                {{/each}}
              </div>
            </section>

            {{#if @scan.policy.assessment}}
              <section
                class="spam-guard-evidence__card spam-guard-evidence__engagement"
              >
                <h3 class="spam-guard-evidence__heading">{{i18n
                    "spam_guard.dashboard.reading"
                  }}</h3>
                {{#if @scan.policy.assessment.engagement.available}}
                  <dl class="spam-guard-evidence__metrics">
                    <div><dt>{{i18n "spam_guard.dashboard.topics"}}</dt><dd
                      >{{dNumber
                          @scan.policy.assessment.engagement.topics_viewed
                        }}</dd></div>
                    <div><dt>{{i18n "spam_guard.dashboard.posts"}}</dt><dd
                      >{{dNumber
                          @scan.policy.assessment.engagement.posts_read
                        }}</dd></div>
                    <div><dt>{{i18n "spam_guard.dashboard.time"}}</dt><dd
                      >{{dFormatDuration
                          @scan.policy.assessment.engagement.reading_seconds
                        }}</dd></div>
                    <div><dt>{{i18n "spam_guard.dashboard.visits"}}</dt><dd
                      >{{dNumber
                          @scan.policy.assessment.engagement.days_visited
                        }}</dd></div>
                  </dl>
                {{/if}}
                <p class="spam-guard-evidence__caption">{{i18n
                    (concat
                      "spam_guard.engagement.levels."
                      @scan.policy.assessment.engagement.level
                    )
                  }}</p>
              </section>

              {{#if @scan.policy.assessment.local_signals.enabled}}
                <section class="spam-guard-evidence__card">
                  <h3 class="spam-guard-evidence__heading">{{i18n
                      "spam_guard.dashboard.local_signals"
                    }}</h3>
                  <dl class="spam-guard-evidence__metrics">
                    <div><dt>{{i18n "spam_guard.dashboard.duplicates"}}</dt><dd
                      >{{dNumber
                          @scan.policy.assessment.local_signals.duplicate_posts
                        }}</dd></div>
                    <div><dt>{{i18n "spam_guard.dashboard.burst_posts"}}</dt><dd
                      >{{dNumber
                          @scan.policy.assessment.local_signals.burst_posts
                        }}</dd></div>
                    <div><dt>{{i18n
                          "spam_guard.dashboard.burst_topics"
                        }}</dt><dd>{{dNumber
                          @scan.policy.assessment.local_signals.burst_topics
                        }}</dd></div>
                    <div><dt>{{i18n
                          "spam_guard.dashboard.confirmed_spam"
                        }}</dt><dd>{{dNumber
                          @scan.policy.assessment.local_signals.confirmed_spam_posts
                        }}</dd></div>
                  </dl>
                </section>
              {{/if}}
            {{/if}}
            {{yield}}
          </div>
        </div>
        <details class="spam-guard-evidence__help">
          <summary>{{i18n "spam_guard.calculation.how"}}</summary>
          {{#if @scan.policy.assessment.calculation}}
            <p>{{i18n "spam_guard.calculation.method"}}</p>
            <p>{{i18n
                "spam_guard.calculation.recency_help"
                full_days=@scan.policy.external_weights.full_weight_days
                half_days=@scan.policy.external_weights.half_weight_days
              }}</p>
          {{else}}
            {{#if @scan.policy.weights}}
              <p>{{i18n
                  "spam_guard.dashboard.configured_weights"
                  spam_points=@scan.policy.weights.confirmed_spam
                  cap=@scan.policy.weights.local_cap
                }}</p>
            {{/if}}
          {{/if}}
          <p>{{i18n "spam_guard.dashboard.local_help"}}</p>
          <p>{{i18n "spam_guard.dashboard.score_help"}}</p>
          <p>{{i18n "spam_guard.evidence_help"}}</p>
        </details>
      {{else}}
        {{#if @exempt}}<SpamGuardRiskScore @exempt={{true}} />{{/if}}
        <p>{{i18n "spam_guard.no_evidence"}}</p>
        {{yield}}
      {{/if}}
    </div>
  </template>
}
