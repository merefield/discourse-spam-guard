import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setPrefix } from "discourse/lib/get-url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import ReviewableSpamGuard from "discourse/plugins/discourse-spam-guard/discourse/components/reviewable-spam-guard";
import SpamGuardDashboard from "discourse/plugins/discourse-spam-guard/discourse/components/spam-guard-dashboard";

module("Integration | Component | SpamGuardDashboard", function (hooks) {
  setupRenderingTest(hooks);
  hooks.beforeEach(() => {
    pretender.get("/u/search/users", () =>
      response({
        users: [
          {
            id: 42,
            username: "someone",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/s/da6949/{size}.png",
          },
        ],
      })
    );
  });

  test("chooses a named user and submits their ID", async function (assert) {
    pretender.post("/admin/plugins/discourse-spam-guard/check", (request) => {
      assert.true(
        request.requestBody.includes("user_id=42"),
        "the selected user's ID reaches the check endpoint"
      );
      return [
        200,
        { "Content-Type": "application/json" },
        JSON.stringify({ scan: null }),
      ];
    });
    const model = { enabled: true, health: {}, mode: "observe", scans: [] };
    await render(<template><SpamGuardDashboard @model={{model}} /></template>);
    const chooser = selectKit(".user-chooser");
    await chooser.expand();
    await chooser.fillInFilter("someone");
    await chooser.selectRowByValue("someone");
    await click('button[type="submit"]');
    assert
      .dom(".spam-guard-dashboard")
      .includesText("exempt", "the completed check is announced");
  });

  test("prefixes dashboard and review links for a subfolder installation", async function (assert) {
    setPrefix("/forum");
    const scan = {
      id: 1,
      user_id: 42,
      username: "someone",
      reviewable_id: 9,
      decision: "allow",
      status: "checked",
      action_taken: "none",
      evidence: [],
    };
    const model = { enabled: true, health: {}, mode: "observe", scans: [scan] };
    const reviewable = {
      spam_guard_user_id: 42,
      spam_guard_username: "someone",
      spam_guard_scan: scan,
    };
    await render(
      <template>
        <SpamGuardDashboard @model={{model}} /><ReviewableSpamGuard
          @reviewable={{reviewable}}
        />
      </template>
    );
    assert
      .dom(
        '.spam-guard-dashboard a[href="/forum/admin/users/42/someone?spamGuard=true#spam-guard"]'
      )
      .exists("the activity link includes the prefix and opens the dashboard");
    assert
      .dom('.spam-guard-dashboard a[href="/forum/review/9"]')
      .exists("the review link includes the prefix");
    assert
      .dom(".spam-guard-review > a")
      .hasAttribute(
        "href",
        "/forum/admin/users/42/someone?spamGuard=true#spam-guard",
        "the queue link includes the prefix"
      );
  });
});
