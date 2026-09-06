import { click, currentURL, render, visit } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import SpamGuardUserSummary from "discourse/plugins/discourse-spam-guard/discourse/components/spam-guard-user-summary";

module("Integration | Component | SpamGuardUserSummary", function (hooks) {
  setupRenderingTest(hooks);

  test("shows the last assessment alongside an exemption and links to the account", async function (assert) {
    const user = {
      id: 42,
      username: "someone",
      spam_guard_summary: {
        exempt: true,
        scan: {
          decision: "silence",
          status: "checked",
          scored: true,
          score: 80,
          checked_at: "2026-09-05T10:00:00Z",
        },
      },
    };
    await render(<template><SpamGuardUserSummary @user={{user}} /></template>);
    assert
      .dom(".spam-guard-risk-score__value")
      .hasText("80%", "the list exposes the saved risk score");
    assert
      .dom(".spam-guard-risk-score")
      .hasClass(
        "--exempt",
        "the manual override takes precedence over risk colour"
      );
    assert
      .dom(".spam-guard-user-summary a")
      .hasAttribute(
        "href",
        "/admin/users/42/someone?spamGuard=true#spam-guard",
        "the account detail page is linked"
      );
    assert
      .dom(".spam-guard-risk-score__override")
      .hasText(
        i18n("spam_guard.dashboard.exempt"),
        "the manual override is explicit"
      );
    assert
      .dom(".spam-guard-user-summary")
      .includesText(
        i18n("spam_guard.dashboard.exempt"),
        "the exemption is distinct from evidence"
      );
    assert
      .dom(".spam-guard-user-summary a")
      .exists({ count: 1 }, "the score box is the single link");
  });

  test("does not portray an unchecked account as a clean lookup", async function (assert) {
    const user = {
      id: 42,
      username: "someone",
      spam_guard_summary: { exempt: false, scan: null },
    };
    await render(<template><SpamGuardUserSummary @user={{user}} /></template>);
    assert
      .dom(".spam-guard-user-summary")
      .includesText(
        i18n("spam_guard.dashboard.na"),
        "absence of retained results is explicit"
      );
    assert
      .dom(".spam-guard-status")
      .doesNotExist("no risk classification is invented");
    assert
      .dom(".spam-guard-risk-score")
      .hasClass("--unknown", "missing scores use a grey box");
  });

  test("renders nothing when no admin summary is supplied", async function (assert) {
    const user = { id: 42, username: "someone" };
    await render(<template><SpamGuardUserSummary @user={{user}} /></template>);
    assert
      .dom(".spam-guard-user-summary")
      .doesNotExist("restricted metadata has no placeholder");
  });
});

acceptance("Spam Guard admin user list", function (needs) {
  needs.user({ admin: true });
  needs.pretender((server, helper) => {
    server.get("/admin/users/42.json", () =>
      helper.response({
        id: 42,
        username: "someone",
        active: true,
        admin: false,
        moderator: false,
        groups: [],
      })
    );
    server.get("/admin/plugins/discourse-spam-guard/accounts/42.json", () =>
      helper.response({
        enabled: false,
        allowed: false,
        scan: {
          status: "checked",
          decision: "watch",
          action_taken: "none",
          created_at: "2026-09-05T10:00:00Z",
          evidence: [],
          policy: {
            assessment: {
              score: 20,
              scored: true,
              external_decision: "watch",
              engagement: { level: "new_account", available: false },
            },
          },
        },
      })
    );
    server.get("/admin/users/list/active.json", () =>
      helper.response([
        {
          id: 42,
          username: "someone",
          active: true,
          spam_guard_summary: {
            exempt: false,
            scan: {
              decision: "watch",
              status: "checked",
              scored: true,
              score: 20,
              checked_at: "2026-09-05T10:00:00Z",
            },
          },
        },
      ])
    );
  });

  test("a dedicated Spam Guard column links the compact score to the expanded dashboard", async function (assert) {
    await visit("/admin/users/list/active");
    assert
      .dom(".spam-guard-column .spam-guard-risk-score__value")
      .hasText("20%", "the live list renders the risk percentage");
    assert
      .dom(".spam-guard-column .spam-guard-risk-score")
      .hasClass("--caution", "the shared colour reaches the real list");
    assert
      .dom(".spam-guard-column .spam-guard-user-summary")
      .isVisible("the connector renders in the real admin list");
    assert
      .dom(".spam-guard-column .spam-guard-status")
      .hasText(
        i18n("spam_guard.dashboard.suspicious"),
        "the supplied summary survives the admin user model"
      );
    assert
      .dom(".spam-guard-column-header")
      .hasText(i18n("spam_guard.title"), "the column has a title");
    assert
      .dom(".user-role .spam-guard-user-summary")
      .doesNotExist("the old Status-cell summary is removed");
    assert
      .dom(".directory-table")
      .hasAttribute(
        "style",
        /repeat\(8,/,
        "the grid allocates the additional column"
      );
    assert
      .dom(".spam-guard-column a")
      .hasAttribute(
        "href",
        "/admin/users/42/someone?spamGuard=true#spam-guard",
        "the link requests an expanded dashboard"
      );
    await click(".spam-guard-user-summary__link");
    assert.true(
      currentURL().includes("spamGuard=true"),
      "the open request survives Discourse's link interception"
    );
    assert
      .dom("#spam-guard .spam-guard-evidence")
      .exists("clicking the box opens the dashboard through the real router");
    assert
      .dom("#spam-guard .spam-guard-risk-score__value")
      .hasText("20%", "the destination loads the account's saved assessment");
  });
});
