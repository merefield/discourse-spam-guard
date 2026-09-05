import { i18n } from "discourse-i18n";
import SpamGuardUserSummary from "../../components/spam-guard-user-summary";

export default <template>
  {{#if @outletArgs.user.spam_guard_summary}}
    <div class="directory-table__cell spam-guard-column">
      <span class="directory-table__label">{{i18n "spam_guard.title"}}</span>
      <SpamGuardUserSummary @user={{@outletArgs.user}} />
    </div>
  {{/if}}
</template>
