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

  def events
    usernames =
      User.where(id: object.events.map { |event| event["actor_id"] }).pluck(:id, :username).to_h
    object.events.map { |event| event.merge("actor_username" => usernames[event["actor_id"]]) }
  end
end
