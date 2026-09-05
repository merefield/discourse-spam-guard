# frozen_string_literal: true

RSpec.describe DiscourseSpamGuard::Policy do
  describe ".assess" do
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
        "score" => 50,
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
      expect(assessment).to include("decision" => "silence", "score" => 75)
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
        { "confidence" => 50 },
        { "confidence" => nil },
        { "blacklisted" => true },
      ].each do |weakness|
        expect(described_class.evaluate("email" => strong.merge(weakness))).to eq("watch")
      end
    end
  end
end
