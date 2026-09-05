import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "spam-guard-user-list",
  initialize(container) {
    if (!container.lookup("service:current-user")?.admin) {
      return;
    }
    withPluginApi((api) => {
      api.modifyClass("controller:admin-user/index", {
        pluginId: "discourse-spam-guard-open-dashboard",
        queryParams: ["spamGuard"],
        spamGuard: false,
      });
      api.registerValueTransformer(
        "admin-user-list-column-count",
        ({ value }) => value + 1
      );
    });
  },
};
