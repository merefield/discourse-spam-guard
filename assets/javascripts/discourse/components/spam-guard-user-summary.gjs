import { concat } from "@ember/helper";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import SpamGuardRiskScore from "./spam-guard-risk-score";

export default <template>
  {{#if @user.spam_guard_summary}}
    <div class="spam-guard-user-summary" ...attributes>
      <a
        class="spam-guard-user-summary__link"
        href={{getURL
          (concat
            "/admin/users/"
            @user.id
            "/"
            @user.username
            "?spamGuard=true#spam-guard"
          )
        }}
      >
        <span class="sr-only">{{i18n
            "spam_guard.open_user_dashboard"
            username=@user.username
          }}</span>
        <SpamGuardRiskScore
          @compact={{true}}
          @exempt={{@user.spam_guard_summary.exempt}}
          @score={{@user.spam_guard_summary.scan.score}}
          @scored={{@user.spam_guard_summary.scan.scored}}
          @decision={{@user.spam_guard_summary.scan.decision}}
          @status={{@user.spam_guard_summary.scan.status}}
        />
      </a>
    </div>
  {{/if}}
</template>
