# frozen_string_literal: true

module DiscourseSpamGuard
  # Recovery and audit access must remain available after automatic checks are disabled.
  # rubocop:disable Discourse/Plugins/CallRequiresPlugin
  class AdminController < ::Admin::AdminController
    before_action :limit_checks, only: %i[check test_connection]

    def index
      scans = Scan.includes(:user).order(id: :desc).limit(50)
      render json: {
               scans: serialize_data(scans, SpamGuardScanSerializer),
               health: Client.health,
               enabled: DiscourseSpamGuard.enabled?,
               mode: SiteSetting.spam_guard_mode,
               counts: Scan.where("created_at >= ?", 7.days.ago).group(:action_taken).count,
             }
    end

    def check
      CheckAccount.call(**service_params) do
        on_success do |scan:|
          render json: {
                   scan: scan && SpamGuardScanSerializer.new(scan, scope: guardian, root: false),
                 }
        end
        on_failure { render_json_error(I18n.t("spam_guard.check_failed")) }
        on_model_not_found(:user) { raise Discourse::NotFound }
        on_failed_policy(:can_check_account) { raise Discourse::InvalidAccess }
      end
    end

    def test_connection
      result = Client.new.lookup({ "ip" => "127.0.0.1" }, bypass_cache: true)
      render json: { status: result["status"], health: Client.health }
    end

    def account
      user = User.find(params[:user_id])
      scan = Scan.where(user: user).latest.first
      render json: {
               allowed: Account.exists?(user: user, allowed: true),
               enabled: DiscourseSpamGuard.enabled?,
               scan: scan && SpamGuardScanSerializer.new(scan, scope: guardian, root: false),
             }
    end

    def update_exception
      UpdateException.call(**service_params) do
        on_success { head :no_content }
        on_failure { render_json_error(I18n.t("spam_guard.check_failed")) }
        on_model_not_found(:user) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_exception) { raise Discourse::InvalidAccess }
      end
    end

    private

    def limit_checks
      RateLimiter.new(current_user, "spam-guard-check", 10, 1.minute).performed!
    end
  end
  # rubocop:enable Discourse/Plugins/CallRequiresPlugin
end
