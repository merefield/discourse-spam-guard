# frozen_string_literal: true

module DiscourseSpamGuard
  class Policy
    def self.settings
      {
        "version" => 4,
        "preset" => SiteSetting.spam_guard_preset,
        "mode" => SiteSetting.spam_guard_mode,
        "email_confidence" => SiteSetting.spam_guard_email_confidence,
        "email_frequency" => SiteSetting.spam_guard_email_frequency,
        "ip_confidence" => SiteSetting.spam_guard_ip_confidence,
        "ip_frequency" => SiteSetting.spam_guard_ip_frequency,
        "max_age_days" => SiteSetting.spam_guard_max_evidence_age_days,
      }
    end

    def self.assess(
      evidence,
      settings,
      engagement:,
      status:,
      local_signals: nil,
      additional_evidence: []
    )
      external = status == "checked" ? evaluate(evidence, settings) : "unknown"
      base = { "allow" => 0, "watch" => 20, "review" => 50, "silence" => 80 }[external]
      score = (base + engagement.fetch("adjustment")).clamp(0, 100) if base
      decision = external
      local_points = local_signals&.fetch("adjustment", 0) || 0
      additional_points = [
        additional_evidence.sum { |entry| entry.fetch("points") },
        AdditionalEvidence::MAX_POINTS,
        LocalSignals::TOTAL_CAP - local_points,
      ].min
      local_points += additional_points
      if score
        decision = "watch" if external == "allow" && score >= 10
        decision = "review" if external == "silence" && score < 75
        score = (base + engagement.fetch("adjustment") + local_points).clamp(0, 100)
        if %w[allow watch].include?(decision)
          decision = "watch" if local_points.positive?
          decision = "review" if local_points >= LocalSignals::POSTING_CAP
        end
      end
      decision = "review" if !score && local_points >= LocalSignals::POSTING_CAP
      {
        "external_decision" => external,
        "scored" => !base.nil?,
        "base_score" => base,
        "score" => score,
        "decision" => decision,
        "engagement" => engagement,
        "local_signals" => local_signals,
        "additional_evidence" => additional_evidence,
        "additional_points" => additional_points,
      }
    end

    def self.evaluate(evidence, settings = self.settings)
      strong =
        %w[email ip].select do |field|
          data = evidence[field]
          seen = Time.zone.parse(data["last_seen"]) if data && data["last_seen"]
          data && data["appears"] && !data["blacklisted"] && seen && seen <= Time.current &&
            seen >= settings["max_age_days"].days.ago &&
            data["frequency"] >= settings["#{field}_frequency"] &&
            data["confidence"].to_f >= settings["#{field}_confidence"]
        end
      if strong.include?("email") && (settings["preset"] == "balanced" || strong.include?("ip"))
        "silence"
      elsif strong.any?
        "review"
      elsif evidence.values.any? { |data| data["appears"] || data["blacklisted"] }
        "watch"
      else
        "allow"
      end
    end
  end
end
