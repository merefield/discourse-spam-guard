import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import SpamGuardEvidence from "../../components/spam-guard-evidence";

export default class SpamGuardAiReview extends Component {
  @service currentUser;

  get visible() {
    return (
      this.args.outletArgs.model.spam_guard_scan ||
      (this.currentUser?.admin &&
        this.args.outletArgs.model.spam_guard_ai_account_id)
    );
  }

  <template>
    {{#if this.visible}}
      <div class="spam-guard-ai-review" ...attributes>
        {{#if @outletArgs.model.spam_guard_scan}}
          <SpamGuardEvidence @scan={{@outletArgs.model.spam_guard_scan}} />
        {{/if}}
        {{#if this.currentUser.admin}}
          {{#if @outletArgs.model.spam_guard_ai_account_id}}
            <a
              href={{getURL
                (concat
                  "/admin/users/"
                  @outletArgs.model.spam_guard_ai_account_id
                  "#spam-guard"
                )
              }}
            >{{i18n "spam_guard.ai.account"}}</a>
          {{/if}}
        {{/if}}
      </div>
    {{/if}}
  </template>
}
