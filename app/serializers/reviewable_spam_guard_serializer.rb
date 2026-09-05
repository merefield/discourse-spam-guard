# frozen_string_literal: true

class ReviewableSpamGuardSerializer < ReviewableSerializer
  attributes :spam_guard_scan, :spam_guard_username, :spam_guard_user_id

  def spam_guard_scan
    scan = object.spam_guard_scan
    SpamGuardScanSerializer.new(scan, scope: scope, root: false).as_json if scan
  end

  def spam_guard_username
    object.target&.username
  end

  def spam_guard_user_id
    object.target_id
  end
end
