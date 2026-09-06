# frozen_string_literal: true

RSpec.describe DiscourseSpamGuard::SubmissionCandidate do
  fab!(:user)
  fab!(:admin)
  fab!(:post) { Fabricate(:spam_guard_confirmed_post, user: user) }

  describe ".latest" do
    it "includes retained public spam with the registration IP and bounded evidence" do
      post.update!(deleted_at: Time.current, raw: "spam & evidence " * 300)
      candidate = described_class.latest(user)
      expect(candidate.payload).to include(
        "email" => user.email,
        "username" => user.username,
        "ip_addr" => user.registration_ip_address.to_s,
      )
      expect(candidate.payload["evidence"]).to eq(
        "#{Discourse.base_url}/t/#{post.topic_id}/#{post.post_number}\n\n#{post.raw.first(2000)}",
      )
    end

    it "excludes accounts without independently confirmed spam" do
      expect(described_class.latest(Fabricate(:user))).to be_nil
      ReviewableFlaggedPost
        .find_by!(target: post)
        .reviewable_scores
        .update_all(status: ReviewableScore.statuses[:pending])
      expect(described_class.latest(user)).to be_nil
    end

    it "excludes automated and non-staff confirmation" do
      [Discourse.system_user, user].each do |reviewer|
        ReviewableFlaggedPost
          .find_by!(target: post)
          .reviewable_scores
          .update_all(reviewed_by_id: reviewer.id)
        expect(described_class.latest(user)).to be_nil
      end
    end

    it "excludes private topics and restricted categories" do
      post.topic.update!(archetype: Archetype.private_message, category_id: nil)
      expect(described_class.latest(user)).to be_nil
      post.topic.update!(
        archetype: Archetype.default,
        category: Fabricate(:category, read_restricted: true),
      )
      expect(described_class.latest(user)).to be_nil
    end

    it "excludes staff, inactive, staged and unconfirmed accounts" do
      [
        { admin: true },
        { moderator: true },
        { active: false },
        { staged: true },
      ].each do |attributes|
        user.assign_attributes(attributes)
        expect(described_class.latest(user)).to be_nil
        user.reload
      end
      user.email_tokens.update_all(confirmed: false)
      expect(described_class.latest(user)).to be_nil
    end

    it "excludes exempt accounts and posts with private addresses" do
      user.update!(registration_ip_address: "192.168.1.5")
      expect(described_class.latest(user)).to be_nil
      user.update!(registration_ip_address: "8.8.4.4")
      DiscourseSpamGuard::Moderation.allow(user, admin)
      expect(described_class.latest(user)).to be_nil
    end
  end

  describe ".from_token" do
    it "binds preview approval to the actor, target, content and expiration" do
      freeze_time
      token = described_class.latest(user).preview_token(admin)
      expect(described_class.from_token(user, admin, token).post.id).to eq(post.id)
      expect(described_class.from_token(user, Fabricate(:admin), token)).to be_nil
      expect(described_class.from_token(Fabricate(:user), admin, token)).to be_nil
      expect(described_class.from_token(user, admin, token + "tampered")).to be_nil
      post.update!(raw: "This evidence was changed after the administrator previewed it.")
      expect(described_class.from_token(user, admin, token)).to be_nil
      token = described_class.latest(user).preview_token(admin)
      freeze_time 11.minutes.from_now
      expect(described_class.from_token(user, admin, token)).to be_nil
    end
  end
end
