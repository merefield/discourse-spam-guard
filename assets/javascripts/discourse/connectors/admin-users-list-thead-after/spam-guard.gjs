import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class SpamGuardColumnHeader extends Component {
  @service currentUser;

  <template>
    {{#if this.currentUser.admin}}
      <div
        class="directory-table__column-header spam-guard-column-header"
      >{{i18n "spam_guard.title"}}</div>
    {{/if}}
  </template>
}
