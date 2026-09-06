# frozen_string_literal: true

class SpamGuardSubmissionPreviewSerializer < ApplicationSerializer
  attributes :username, :email, :ip_address, :evidence, :post_id, :token
  def username
    object.payload["username"]
  end
  def email
    object.payload["email"]
  end
  def ip_address
    object.payload["ip_addr"]
  end
  def evidence
    object.payload["evidence"]
  end
  def post_id
    object.post.id
  end
  def token
    object.preview_token(scope.user)
  end
end
