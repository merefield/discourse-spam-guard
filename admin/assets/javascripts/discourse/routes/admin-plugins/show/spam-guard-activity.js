import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class SpamGuardActivityRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/plugins/discourse-spam-guard/activity.json");
  }
}
