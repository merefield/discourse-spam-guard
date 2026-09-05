# frozen_string_literal: true

# name: discourse-spam-guard
# about: Explainable Stop Forum Spam reputation checks and moderation tools.
# version: 0.1.2
# authors: Robert Barrow
# url: https://github.com/merefield/discourse-spam-guard

enabled_site_setting :spam_guard_enabled
register_asset "stylesheets/common/spam-guard.scss"
%w[
  circle-check
  circle-exclamation
  circle-question
  triangle-exclamation
  user-check
  user-slash
].each { |icon| register_svg_icon icon }
add_admin_route "spam_guard.title", "discourse-spam-guard", use_new_show_route: true

module ::DiscourseSpamGuard
  PLUGIN_NAME = "discourse-spam-guard"
  EXTENSION_API_VERSION = 1

  def self.enabled?
    SiteSetting.spam_guard_enabled
  end
end

require_relative "lib/discourse_spam_guard/engine"

after_initialize do
  register_reviewable_type ReviewableSpamGuard

  reloadable_patch do
    Admin::UsersController.prepend(DiscourseSpamGuard::CoreExtensions::AdminUsersController)
    Reviewable.singleton_class.prepend(DiscourseSpamGuard::CoreExtensions::ReviewableQuery)
  end

  add_to_serializer(
    :admin_user_list,
    :spam_guard_summary,
    respect_plugin_enabled: false,
    include_condition: -> do
      scope.is_admin? && object.instance_variable_defined?(:@spam_guard_summary)
    end,
  ) { object.instance_variable_get(:@spam_guard_summary) }

  on(:user_created) do |user|
    if DiscourseSpamGuard.enabled? && user.human? && !user.staff?
      Jobs.enqueue(:spam_guard_check, user_id: user.id, source: "registration")
      hours = SiteSetting.spam_guard_recheck_hours
      if hours > 0
        Jobs.enqueue_in(hours.hours, :spam_guard_check, user_id: user.id, source: "recheck")
      end
    end
  end

  on(:post_created) do |post, *_args|
    if post.post_type == Post.types[:regular] && post.topic&.archetype == Archetype.default &&
         !post.topic.category&.read_restricted?
      DiscourseSpamGuard::LocalSignals.enqueue(post.user)
    end
  end

  on(:reviewable_transitioned_to) do |_status, reviewable|
    if reviewable.is_a?(ReviewableFlaggedPost)
      DiscourseSpamGuard::LocalSignals.enqueue(reviewable.target_created_by)
    end
  end

  # Privacy cleanup must also run while automatic checking is disabled.
  # rubocop:disable Discourse/Plugins/UsePluginInstanceOn
  DiscourseEvent.on(:user_destroyed) do |user|
    DiscourseSpamGuard::Scan.where(user_id: user.id).delete_all
    DiscourseSpamGuard::Account.where(user_id: user.id).delete_all
  end

  DiscourseEvent.on(:user_anonymized) do |user:, **_opts|
    DiscourseSpamGuard::Scan.where(user_id: user.id).delete_all
    DiscourseSpamGuard::Account.where(user_id: user.id).delete_all
  end
  # rubocop:enable Discourse/Plugins/UsePluginInstanceOn
end
