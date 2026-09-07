# frozen_string_literal: true

module Jobs
  class SpamGuardReconcileAi < ::Jobs::Base
    def execute(args)
      DiscourseSpamGuard::AiIntegration.reconcile(User.find_by(id: args[:user_id]))
    end
  end
end
