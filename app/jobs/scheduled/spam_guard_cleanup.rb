# frozen_string_literal: true

module Jobs
  class SpamGuardCleanup < ::Jobs::Scheduled
    every 1.day

    def execute(_args)
      DiscourseSpamGuard::Scan.expire!
      DiscourseSpamGuard::Account.where.not(user_id: User.select(:id)).in_batches.delete_all
      DiscourseSpamGuard::Scan.where.not(user_id: User.select(:id)).in_batches.delete_all
    end
  end
end
