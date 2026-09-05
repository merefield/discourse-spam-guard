import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import SpamGuardRiskScore from "discourse/plugins/discourse-spam-guard/discourse/components/spam-guard-risk-score";

module("Integration | Component | SpamGuardRiskScore", function (hooks) {
  setupRenderingTest(hooks);

  test("zero is a scored result and remains distinct from unavailable", async function (assert) {
    await render(
      <template>
        <SpamGuardRiskScore
          @score={{0}}
          @scored={{true}}
          @status="checked"
          @decision="allow"
        />
      </template>
    );
    assert
      .dom(".spam-guard-risk-score__value")
      .hasText("0%", "zero is displayed rather than treated as absent");
    assert
      .dom(".spam-guard-risk-score")
      .hasClass("--clear", "a clear assessment uses the success colour");
    assert
      .dom(".spam-guard-risk-score__note")
      .hasText(
        i18n("spam_guard.dashboard.score_note"),
        "the score is distinguished from a probability"
      );
  });

  test("an unavailable check cannot display a misleading zero", async function (assert) {
    await render(
      <template>
        <SpamGuardRiskScore
          @score={{0}}
          @scored={{true}}
          @status="unknown"
          @decision="unknown"
          @compact={{true}}
        />
      </template>
    );
    assert
      .dom(".spam-guard-risk-score__value")
      .doesNotExist("an outage has no numerical score");
    assert
      .dom(".spam-guard-risk-score__unscored")
      .hasText(
        i18n("spam_guard.dashboard.na"),
        "the absence of a score is explicit"
      );
    assert
      .dom(".spam-guard-risk-score")
      .hasClass("--unknown", "the outage colour is neutral");
  });

  test("reading does not turn unresolved evidence green at zero points", async function (assert) {
    await render(
      <template>
        <SpamGuardRiskScore
          @score={{0}}
          @scored={{true}}
          @status="checked"
          @decision="watch"
        />
      </template>
    );
    assert
      .dom(".spam-guard-risk-score__value")
      .hasText("0%", "the actual adjusted score is preserved");
    assert
      .dom(".spam-guard-risk-score")
      .hasClass("--caution", "the evidence floor is reflected in the colour");
    assert
      .dom(".spam-guard-status")
      .hasText(
        i18n("spam_guard.decisions.watch"),
        "the retained concern is explained in text"
      );
  });
});
