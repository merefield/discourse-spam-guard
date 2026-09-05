import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "spam-guard",
  initialize(container) {
    withPluginApi((api) => {
      api.registerReviewableComponent(
        "ReviewableSpamGuard",
        async () =>
          (await import("../components/reviewable-spam-guard")).default
      );
      if (container.lookup("service:current-user")?.admin) {
        api.addAdminPluginConfigurationNav("discourse-spam-guard", [
          {
            label: "spam_guard.activity",
            route: "adminPlugins.show.spam-guard-activity",
            description: "spam_guard.description",
          },
        ]);
      }
    });
  },
};
