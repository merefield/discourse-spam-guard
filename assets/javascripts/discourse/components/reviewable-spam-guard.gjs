import { concat } from "@ember/helper";
import getURL from "discourse/lib/get-url";
import SpamGuardEvidence from "./spam-guard-evidence";

export default <template>
  <div class="spam-guard-review" ...attributes>
    <a
      href={{getURL
        (concat
          "/admin/users/"
          @reviewable.spam_guard_user_id
          "/"
          @reviewable.spam_guard_username
          "?spamGuard=true#spam-guard"
        )
      }}
    >
      {{@reviewable.spam_guard_username}}
    </a>
    <SpamGuardEvidence @scan={{@reviewable.spam_guard_scan}} />
  </div>
</template>
