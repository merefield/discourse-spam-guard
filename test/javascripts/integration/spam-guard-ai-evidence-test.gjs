import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import SpamGuardAiEvidence from "discourse/plugins/discourse-spam-guard/discourse/components/spam-guard-ai-evidence";
import SpamGuardUser from "discourse/plugins/discourse-spam-guard/discourse/components/spam-guard-user";

module("Integration | Component | SpamGuardAiEvidence", function (hooks) {
  setupRenderingTest(hooks);

  test("staff rejection is distinct from AI classification and explanations are escaped", async function (assert) {
    this.currentUser.set("admin", true);
    const evidence = {
      entries: [
        {
          post_id: 1,
          post_url: "/t/1/1",
          reviewable_id: 2,
          is_spam: true,
          outcome: "rejected",
          reason: "<img src=x onerror=alert(1)>",
          checked_at: "2026-09-07T10:00:00Z",
        },
      ],
    };
    await render(
      <template><SpamGuardAiEvidence @evidence={{evidence}} /></template>
    );
    assert
      .dom(".spam-guard-ai-evidence h4")
      .hasText(
        i18n("spam_guard.ai.outcome.rejected"),
        "human decision is prominent"
      );
    assert
      .dom(".spam-guard-ai-evidence")
      .includesText(
        i18n("spam_guard.ai.spam"),
        "the automated finding is separately labelled"
      );
    assert
      .dom(".spam-guard-ai-evidence__reason")
      .hasText(evidence.entries[0].reason, "explanation is plain text");
    assert
      .dom(".spam-guard-ai-evidence img")
      .doesNotExist("explanation cannot inject HTML");
    assert
      .dom(".spam-guard-ai-evidence__actions button")
      .doesNotExist("rejected flags do not offer reporting");
    assert
      .dom('.spam-guard-ai-evidence a[href="/review/2"]')
      .exists("staff can open the original review");
  });

  test("AI evidence is hidden from moderators", async function (assert) {
    this.currentUser.setProperties({ admin: false, moderator: true });
    const evidence = { entries: [] };
    await render(
      <template><SpamGuardAiEvidence @evidence={{evidence}} /></template>
    );
    assert
      .dom(".spam-guard-ai-evidence")
      .doesNotExist("admin-only evidence stays hidden");
  });

  test("refresh reads saved evidence and confirmed findings open the existing approval dialog", async function (assert) {
    this.currentUser.set("admin", true);
    const user = { id: 42, admin: false, moderator: false };
    let loads = 0;
    let previews = 0;
    pretender.get(
      "/admin/plugins/discourse-spam-guard/accounts/42.json",
      () => {
        loads++;
        return response({
          enabled: false,
          allowed: false,
          scan: null,
          submission_configured: true,
          ai_evidence: {
            entries: [
              {
                post_id: 1,
                post_url: "/t/1/1",
                is_spam: true,
                outcome: "confirmed",
                checked_at: "2026-09-07T10:00:00Z",
              },
            ],
          },
        });
      }
    );
    pretender.get(
      "/admin/plugins/discourse-spam-guard/accounts/42/submission.json",
      () => {
        previews++;
        return response({
          configured: true,
          preview: {
            destination: "https://www.stopforumspam.com/add",
            username: "spammer",
            email: "spam@example.com",
            ip_address: "8.8.4.4",
            evidence: "https://forum.example/t/1/1\nConfirmed spam",
            token: "signed-preview",
          },
        });
      }
    );
    await render(
      <template><ModalContainer /><SpamGuardUser @user={{user}} /></template>
    );
    await click(".spam-guard-user__toggle");
    await click(".spam-guard-ai-evidence > button");
    assert.strictEqual(
      loads,
      2,
      "refresh fetches saved evidence without a new reputation or AI check"
    );
    await click(".spam-guard-ai-evidence__actions button");
    assert.strictEqual(previews, 1, "the account preview is fetched");
    assert
      .dom(".spam-guard-submission-confirmation")
      .includesText(
        "spam@example.com",
        "the exact identifiers are shown before approval"
      );
    await click(".spam-guard-submission-confirmation__cancel");
    assert
      .dom(".spam-guard-submission-confirmation")
      .doesNotExist("cancel closes the dialog without submitting");
  });
});
