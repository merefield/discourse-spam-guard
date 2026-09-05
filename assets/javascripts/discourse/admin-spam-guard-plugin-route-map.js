export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("spam-guard-activity", { path: "activity" });
  },
};
