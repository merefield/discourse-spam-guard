import Component from "@glimmer/component";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import SpamGuardStatus from "./spam-guard-status";

export default class SpamGuardRiskScore extends Component {
  get hasScore() {
    return (
      this.args.status === "checked" &&
      this.args.scored &&
      Number.isFinite(this.args.score) &&
      this.args.score >= 0 &&
      this.args.score <= 100
    );
  }

  get riskModifier() {
    if (this.args.exempt) {
      return "--exempt";
    }
    if (!this.hasScore) {
      return "--unknown";
    }
    if (this.args.score >= 70) {
      return "--strong";
    }
    if (this.args.score > 30) {
      return "--moderate";
    }
    return this.args.score > 0 ? "--caution" : "--clear";
  }

  get riskLabel() {
    const labels = {
      "--clear": "no_scored_concern",
      "--caution": "suspicious",
      "--moderate": "moderate_concern",
      "--strong": "high_concern",
    };
    return i18n(`spam_guard.dashboard.${labels[this.riskModifier]}`);
  }

  <template>
    <div
      class={{dConcatClass
        "spam-guard-risk-score"
        this.riskModifier
        (if @compact "--compact")
      }}
      ...attributes
    >
      {{#unless @compact}}<span class="spam-guard-risk-score__label">{{i18n
            "spam_guard.dashboard.risk_score"
          }}</span>{{/unless}}
      {{#if this.hasScore}}
        <strong class="spam-guard-risk-score__value">{{i18n
            "spam_guard.dashboard.percentage"
            value=@score
          }}</strong>
      {{else}}
        <strong class="spam-guard-risk-score__unscored">{{i18n
            (if
              @compact
              "spam_guard.dashboard.na"
              "spam_guard.dashboard.not_scored"
            )
          }}</strong>
      {{/if}}
      {{#if @exempt}}
        <span class="spam-guard-risk-score__override">{{i18n
            "spam_guard.dashboard.exempt"
          }}</span>
        {{#unless @compact}}
          <span class="spam-guard-risk-score__note">{{i18n
              "spam_guard.dashboard.exempt_note"
            }}</span>
        {{/unless}}
      {{else if this.hasScore}}
        <span class="spam-guard-status">{{this.riskLabel}}</span>
      {{else if @compact}}
        <span class="spam-guard-risk-score__label">{{i18n
            "spam_guard.dashboard.not_scored"
          }}</span>
      {{else}}
        <SpamGuardStatus @decision={{@decision}} @status={{@status}} />
      {{/if}}
      {{#unless @compact}}<span class="spam-guard-risk-score__note">{{i18n
            "spam_guard.dashboard.score_note"
          }}</span>{{/unless}}
    </div>
  </template>
}
