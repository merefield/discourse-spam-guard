# frozen_string_literal: true

RSpec.describe DiscourseSpamGuard::LocalSignals do
  fab!(:user)
  fab!(:admin)

  before do
    freeze_time
    SiteSetting.spam_guard_enabled = true
    SiteSetting.spam_guard_local_signals = true
    Jobs.run_later!
  end

  describe ".snapshot" do
    it "leaves an inactive unconfirmed account neutral" do
      user.update!(active: false, created_at: 3.days.ago)

      expect(described_class.snapshot(user)).to include(
        "adjustment" => 0,
        "duplicate_posts" => 0,
        "burst_posts" => 0,
        "confirmed_spam_posts" => 0,
      )
    end

    it "caps correlated duplicate and burst evidence" do
      topics = Fabricate.times(3, :topic)
      raw = "An identical substantial post repeated across several public topics."
      5.times { |index| Fabricate(:post, user: user, topic: topics[index % 3], raw: raw) }

      expect(described_class.snapshot(user)).to include(
        "duplicate_posts" => 5,
        "duplicate_points" => 20,
        "burst_posts" => 5,
        "burst_topics" => 3,
        "burst_points" => 15,
        "posting_points" => 25,
        "adjustment" => 25,
      )
    end

    it "does not penalize a busy conversation within one topic" do
      topic = Fabricate(:topic)
      5.times { Fabricate(:post, user: user, topic: topic) }

      expect(described_class.snapshot(user)).to include("burst_points" => 0, "adjustment" => 0)
    end

    it "does not interpret short replies or differently worded content as duplicates" do
      %w[Thanks! Thanks! Thanks!].each { |raw| Fabricate(:post, user: user, raw: raw) }
      3.times do |index|
        Fabricate(
          :post,
          user: user,
          raw: "A substantial and separately worded reply number #{index}.",
        )
      end

      expect(described_class.snapshot(user)["duplicate_points"]).to eq(0)
    end

    it "excludes deleted posts, private messages, restricted topics and other users" do
      raw = "An identical substantial post repeated across several public topics."
      Fabricate(:post, user: user, raw: raw)
      Fabricate(:post, user: user, raw: raw, deleted_at: 1.minute.ago)
      private_topic = Fabricate(:private_message_topic, user: user)
      Fabricate(:post, user: user, topic: private_topic, raw: raw)
      restricted = Fabricate(:category, read_restricted: true)
      Fabricate(:post, user: user, topic: Fabricate(:topic, category: restricted), raw: raw)
      Fabricate(:post, raw: raw)

      expect(described_class.snapshot(user)).to include("posts_sampled" => 1, "adjustment" => 0)
    end

    it "expires posting evidence and ignores future timestamps" do
      3.times do
        Fabricate(:post, user: user, created_at: 25.hours.ago)
        Fabricate(:post, user: user, created_at: 1.hour.from_now)
      end

      expect(described_class.snapshot(user)).to include("posts_sampled" => 0, "adjustment" => 0)
    end

    it "counts distinct staff-confirmed spam posts and caps the total" do
      3.times do
        post = Fabricate(:post, user: user)
        reviewable =
          Fabricate(
            :reviewable_flagged_post,
            target: post,
            target_created_by: user,
            status: :approved,
            reviewable_scores: [],
          )
        2.times do
          Fabricate(
            :reviewable_score,
            reviewable: reviewable,
            reviewable_score_type: ReviewableScore.types[:spam],
            reviewed_by: admin,
            reviewed_at: 1.day.ago,
            status: :agreed,
          )
        end
      end

      expect(described_class.snapshot(user)).to include(
        "confirmed_spam_posts" => 3,
        "history_points" => 50,
        "adjustment" => 50,
      )
    end

    it "excludes unresolved, reversed, non-spam, automated and expired decisions" do
      [
        { status: :pending },
        { status: :disagreed },
        { reviewable_score_type: ReviewableScore.types[:off_topic] },
        { reviewed_by: Discourse.system_user },
        { reviewed_by: user },
        { reviewed_at: 31.days.ago },
      ].each do |attributes|
        reviewable =
          Fabricate(
            :reviewable_flagged_post,
            target_created_by: user,
            status: :approved,
            reviewable_scores: [],
          )
        Fabricate(
          :reviewable_score,
          **{
            reviewable: reviewable,
            status: :agreed,
            reviewable_score_type: ReviewableScore.types[:spam],
            reviewed_by: admin,
            reviewed_at: Time.current,
          }.merge(attributes),
        )
      end
      own_review =
        Fabricate(
          :reviewable,
          type: "ReviewableSpamGuard",
          target: user,
          target_created_by: user,
          status: :approved,
        )
      Fabricate(
        :reviewable_score,
        reviewable: own_review,
        reviewable_score_type: ReviewableScore.types[:spam],
        reviewed_by: admin,
        reviewed_at: Time.current,
        status: :agreed,
      )

      expect(described_class.snapshot(user)["confirmed_spam_posts"]).to eq(0)
    end

    it "removes history evidence when staff reverse their agreement" do
      reviewable =
        Fabricate(:reviewable_flagged_post, target_created_by: user, reviewable_scores: [])
      reviewable.add_score(user, ReviewableScore.types[:spam])
      reviewable.perform(admin, :agree_and_keep)
      expect(described_class.snapshot(user)["confirmed_spam_posts"]).to eq(1)

      reviewable.reviewable_scores.update_all(status: ReviewableScore.statuses[:disagreed])

      expect(described_class.snapshot(user)["confirmed_spam_posts"]).to eq(0)
    end

    it "can be disabled independently of external reputation checks" do
      SiteSetting.spam_guard_local_signals = false

      expect(described_class.snapshot(user)).to eq("enabled" => false, "adjustment" => 0)
    end
  end

  describe ".enqueue" do
    it "checks public posting through the real post-created event" do
      topic = Fabricate(:topic)
      expect_enqueued_with(
        job: :spam_guard_check,
        args: {
          user_id: user.id,
          source: "activity",
        },
      ) { create_post(user: user, topic_id: topic.id) }
    end

    it "checks an account after staff review a spam flag" do
      reviewable =
        Fabricate(:reviewable_flagged_post, target_created_by: user, reviewable_scores: [])
      reviewable.add_score(user, ReviewableScore.types[:spam])

      expect_enqueued_with(
        job: :spam_guard_check,
        args: {
          user_id: user.id,
          source: "activity",
        },
      ) { reviewable.perform(admin, :agree_and_keep) }
    end

    it "schedules an eligible account check one minute later" do
      expect_enqueued_with(
        job: :spam_guard_check,
        args: {
          user_id: user.id,
          source: "activity",
        },
        at: 1.minute.from_now,
      ) { described_class.enqueue(user) }
    end

    it "skips exempt and established accounts and staff" do
      DiscourseSpamGuard::Moderation.allow(user, admin)
      established = Fabricate(:user, created_at: 8.days.ago)
      trusted = Fabricate(:user, trust_level: 2)

      expect_not_enqueued_with(job: :spam_guard_check) do
        [user, admin, established, trusted].each { |account| described_class.enqueue(account) }
      end
    end
  end
end
