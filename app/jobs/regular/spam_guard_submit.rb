# frozen_string_literal: true

module Jobs
  class SpamGuardSubmit < ::Jobs::Base
    def execute(args)
      report = DiscourseSpamGuard::Submission.find_by(id: args[:submission_id])
      return unless report
      candidate = nil
      report.with_lock do
        return unless report.status == "pending"
        return if report.last_attempt_at && report.last_attempt_at > 1.minute.ago
        candidate = report.candidate
        unless candidate
          report.finish!("cancelled", "eligibility_changed")
          return
        end
        report.attempts += 1
        report.last_attempt_at = Time.current
        report.finish!("sending")
      end
      state, code = DiscourseSpamGuard::SubmissionClient.new.submit(candidate.payload)
      report.with_lock do
        return unless report.status == "sending"
        state = "failed" if state == "pending" &&
          report.attempts >= DiscourseSpamGuard::Submission::MAX_ATTEMPTS
        report.finish!(state, code)
      end
      Jobs.enqueue_in(1.minute, :spam_guard_submit, submission_id: report.id) if state == "pending"
    end
  end
end
