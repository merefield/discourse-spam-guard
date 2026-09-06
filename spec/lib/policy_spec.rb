# frozen_string_literal: true

module DiscourseSpamGuard::PolicySpecHelpers
  def assess(evidence, adjustment: 0, settings: described_class.settings)
    described_class.assess(
      evidence,
      settings,
      engagement: {
        "adjustment" => adjustment,
      },
      status: "checked",
    )
  end
end

RSpec.describe DiscourseSpamGuard::Policy do
  describe ".assess" do
    it "retains review for confirmed spam even when its configured contribution is zero" do
      SiteSetting.spam_guard_local_points_cap = 0
      %w[checked unknown].each do |status|
        assessment =
          described_class.assess(
            {},
            described_class.settings,
            engagement: {
              "adjustment" => -15,
            },
            status: status,
            local_signals: {
              "confirmed_spam_posts" => 1,
              "adjustment" => 0,
            },
          )
        expect(assessment["decision"]).to eq("review")
      end
    end

    it "applies the configured combined cap to local and extension evidence" do
      SiteSetting.spam_guard_local_points_cap = 90
      assessment =
        described_class.assess(
          {},
          described_class.settings,
          engagement: {
            "adjustment" => -15,
          },
          status: "checked",
          local_signals: {
            "confirmed_spam_posts" => 1,
            "adjustment" => 80,
          },
          additional_evidence: [{ "label" => "Additional evidence", "points" => 25 }],
        )
      expect(assessment).to include(
        "score" => 90,
        "additional_points" => 25,
        "decision" => "review",
      )
    end
    it "requests local review during an outage without inventing an external score" do
      assessment =
        described_class.assess(
          {},
          described_class.settings,
          engagement: {
            "adjustment" => -30,
          },
          status: "unknown",
          local_signals: {
            "enabled" => true,
            "adjustment" => 50,
          },
        )
      expect(assessment).to include(
        "external_decision" => "unknown",
        "decision" => "review",
        "score" => nil,
        "scored" => false,
      )
    end

    it "caps additional evidence and never promotes it to automatic silence" do
      assessment =
        described_class.assess(
          {},
          described_class.settings,
          engagement: {
            "adjustment" => 0,
          },
          status: "checked",
          additional_evidence: [{ "label" => "Example", "points" => 25 }] * 10,
        )
      expect(assessment).to include(
        "additional_points" => 25,
        "score" => 25,
        "decision" => "review",
      )
    end
    let(:evidence) do
      data = {
        "appears" => true,
        "frequency" => 20,
        "confidence" => 99,
        "last_seen" => 1.day.ago.iso8601,
      }
      { "email" => data, "ip" => data }
    end

    it "keeps strong evidence actionable even with maximum reassurance" do
      assessment =
        described_class.assess(
          evidence,
          described_class.settings,
          engagement: {
            "adjustment" => -30,
          },
          status: "checked",
        )
      expect(assessment).to include(
        "external_decision" => "silence",
        "decision" => "review",
        "score" => 60,
      )
    end

    it "keeps the silence recommendation after only a minimal amount of reading" do
      assessment =
        described_class.assess(
          evidence,
          described_class.settings,
          engagement: {
            "adjustment" => -5,
          },
          status: "checked",
        )
      expect(assessment).to include("decision" => "silence", "score" => 85)
    end

    it "never interprets engagement as a result when the provider is unavailable or skipped" do
      %w[unknown skipped].each do |status|
        [-30, 10].each do |adjustment|
          assessment =
            described_class.assess(
              {},
              described_class.settings,
              engagement: {
                "adjustment" => adjustment,
              },
              status: status,
            )
          expect(assessment).to include("decision" => "unknown", "score" => nil, "scored" => false)
        end
      end
    end

    it "retains weak external evidence even when reassurance reduces the score to zero" do
      assessment =
        described_class.assess(
          { "username" => evidence["email"] },
          described_class.settings,
          engagement: {
            "adjustment" => -30,
          },
          status: "checked",
        )
      expect(assessment).to include("decision" => "watch", "score" => 0)
    end
  end

  describe "external scoring tiers" do
    let(:email) do
      {
        "appears" => true,
        "frequency" => 9,
        "confidence" => 66.67,
        "last_seen" => 21.hours.ago.iso8601,
      }
    end
    let(:ip) do
      {
        "appears" => true,
        "frequency" => 2,
        "confidence" => 1.01,
        "last_seen" => 20.days.ago.iso8601,
      }
    end

    include DiscourseSpamGuard::PolicySpecHelpers

    it "scores recent moderate email evidence at 60 with no reading and requests review" do
      result = assess({ "email" => email, "ip" => ip }, adjustment: 10)
      expect(result).to include("base_score" => 50, "score" => 60, "decision" => "review")
      expect(result["external_scoring"]).to include(
        "tiers" => {
          "email" => "moderate",
          "ip" => "weak",
        },
        "points" => {
          "email" => 50,
          "ip" => 20,
        },
        "combined" => false,
      )
    end

    it "uses distinct default weights without summing correlated identifiers" do
      strong = email.merge("frequency" => 20, "confidence" => 99)
      moderate_ip = ip.merge("frequency" => 5, "confidence" => 50)
      [
        [{ "email" => strong }, 85, "review"],
        [{ "ip" => moderate_ip }, 30, "watch"],
        [{ "ip" => strong }, 50, "review"],
        [{ "email" => email, "ip" => moderate_ip }, 50, "review"],
        [{ "email" => strong, "ip" => strong }, 90, "silence"],
      ].each do |evidence, points, decision|
        expect(assess(evidence)).to include("score" => points, "decision" => decision)
      end
    end

    it "requires both moderate thresholds and a recent, dated, valid match" do
      freeze_time Time.current.change(usec: 0)
      boundary =
        email.merge("frequency" => 3, "confidence" => 50, "last_seen" => 30.days.ago.iso8601)
      expect(assess({ "email" => boundary })).to include("score" => 50, "decision" => "review")
      [
        { "frequency" => 2 },
        { "confidence" => 49.99 },
        { "confidence" => nil },
        { "last_seen" => 30.days.ago.advance(seconds: -1).iso8601 },
        { "last_seen" => 1.second.from_now.iso8601 },
        { "last_seen" => nil },
        { "blacklisted" => true },
      ].each do |weakness|
        expect(assess({ "email" => boundary.merge(weakness) })).to include(
          "score" => 20,
          "decision" => "watch",
        )
      end
      expect(assess({ "email" => boundary.merge("appears" => false) })).to include(
        "score" => 0,
        "decision" => "allow",
      )
    end

    it "uses saved configurable thresholds and weights without changing earlier assessments" do
      saved = described_class.settings
      before = assess({ "email" => email }, settings: saved)
      SiteSetting.spam_guard_email_moderate_points = 65
      expect(assess({ "email" => email })).to include("score" => 65, "decision" => "review")
      SiteSetting.spam_guard_email_moderate_frequency = 10
      expect(assess({ "email" => email })).to include("score" => 20, "decision" => "watch")
      expect(assess({ "email" => email }, settings: saved)).to eq(before)
    end

    it "does not let numeric weights grant silencing or suppress evidence-based review" do
      SiteSetting.spam_guard_email_moderate_points = 100
      SiteSetting.spam_guard_external_weak_points = 100
      expect(assess({ "email" => email }, adjustment: 10)).to include(
        "score" => 100,
        "decision" => "review",
      )
      expect(assess({ "username" => email })).to include("score" => 100, "decision" => "watch")
      SiteSetting.spam_guard_external_weak_points = 0
      SiteSetting.spam_guard_email_moderate_points = 0
      expect(assess({ "email" => email })).to include("score" => 0, "decision" => "review")
    end

    it "keeps preset scoring consistent and preserves the reading safeguard independently of weights" do
      strong = email.merge("frequency" => 20, "confidence" => 99)
      expect(assess({ "email" => strong })).to include("score" => 85, "decision" => "review")
      SiteSetting.spam_guard_preset = "balanced"
      expect(assess({ "email" => strong })).to include("score" => 85, "decision" => "silence")
      SiteSetting.spam_guard_email_strong_points = 100
      expect(assess({ "email" => strong }, adjustment: -10)).to include(
        "score" => 90,
        "decision" => "review",
      )
    end
  end

  describe "local signal assessment" do
    it "requests review for combined posting evidence even with positive reading" do
      assessment =
        described_class.assess(
          {},
          described_class.settings,
          engagement: {
            "adjustment" => -30,
          },
          local_signals: {
            "adjustment" => 25,
          },
          status: "checked",
        )

      expect(assessment).to include(
        "score" => 0,
        "decision" => "review",
        "external_decision" => "allow",
      )
    end

    it "treats an isolated posting signal as watch and never silences on local evidence" do
      { 15 => "watch", 20 => "watch", 25 => "review", 50 => "review" }.each do |points, decision|
        assessment =
          described_class.assess(
            {},
            described_class.settings,
            engagement: {
              "adjustment" => 0,
            },
            local_signals: {
              "adjustment" => points,
            },
            status: "checked",
          )

        expect(assessment).to include("score" => points, "decision" => decision)
      end
    end

    it "cannot use local points to reverse reading's reduction of a silence recommendation" do
      evidence =
        %w[email ip].index_with do
          {
            "appears" => true,
            "frequency" => 20,
            "confidence" => 99,
            "last_seen" => 1.day.ago.iso8601,
          }
        end
      assessment =
        described_class.assess(
          evidence,
          described_class.settings,
          engagement: {
            "adjustment" => -30,
          },
          local_signals: {
            "adjustment" => 50,
          },
          status: "checked",
        )

      expect(assessment).to include("score" => 100, "decision" => "review")
    end

    it "permits local review during an unavailable lookup without a risk percentage" do
      assessment =
        described_class.assess(
          {},
          described_class.settings,
          engagement: {
            "adjustment" => 0,
          },
          local_signals: {
            "adjustment" => 50,
          },
          status: "unknown",
        )

      expect(assessment).to include("score" => nil, "scored" => false, "decision" => "review")
    end
  end

  describe ".evaluate" do
    let(:strong) do
      {
        "appears" => true,
        "frequency" => 20,
        "confidence" => 99,
        "last_seen" => 1.day.ago.iso8601,
        "blacklisted" => false,
      }
    end

    it "allows accounts without matches" do
      expect(described_class.evaluate({})).to eq("allow")
    end

    it "requires corroboration to recommend silencing with the conservative preset" do
      expect(described_class.evaluate("email" => strong)).to eq("review")
      expect(described_class.evaluate("email" => strong, "ip" => strong)).to eq("silence")
    end

    it "accepts strong email evidence alone with the balanced preset" do
      SiteSetting.spam_guard_preset = "balanced"

      expect(described_class.evaluate("email" => strong)).to eq("silence")
      expect(described_class.evaluate("ip" => strong)).to eq("review")
    end

    it "treats username matches as informational" do
      expect(described_class.evaluate("username" => strong)).to eq("watch")
    end

    it "requires recent, sufficiently frequent, confident exact matches" do
      [
        { "last_seen" => 31.days.ago.iso8601 },
        { "last_seen" => 1.day.from_now.iso8601 },
        { "last_seen" => nil },
        { "frequency" => 1 },
        { "confidence" => 49 },
        { "confidence" => nil },
        { "blacklisted" => true },
      ].each do |weakness|
        expect(described_class.evaluate("email" => strong.merge(weakness))).to eq("watch")
      end
    end
  end
end
