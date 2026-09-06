# frozen_string_literal: true

module Jobs
  class SpamGuardSubmissionRecovery < ::Jobs::Scheduled
    every 5.minutes

    def execute(_args)
      DiscourseSpamGuard::Submission
        .where(status: "sending")
        .where("updated_at < ?", 1.minute.ago)
        .limit(100)
        .each do |report|
          report.with_lock do
            report.finish!("unknown", "delivery_uncertain") if report.status == "sending"
          end
        end
      DiscourseSpamGuard::Submission
        .where(status: "pending")
        .where("updated_at < ?", 1.minute.ago)
        .limit(100)
        .pluck(:id)
        .each { |id| Jobs.enqueue(:spam_guard_submit, submission_id: id) }
    end
  end
end
