# frozen_string_literal: true

class SpamGuardSubmissionSerializer < ApplicationSerializer
  attributes :id,
             :status,
             :attempts,
             :approved_at,
             :last_attempt_at,
             :completed_at,
             :error_code,
             :events
end
