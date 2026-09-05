# frozen_string_literal: true

module DiscourseSpamGuard
  class Policy
    def self.weights
      {
        "reading_limited" => SiteSetting.spam_guard_reading_limited_adjustment,
        "reading_meaningful" => SiteSetting.spam_guard_reading_meaningful_adjustment,
        "reading_sustained" => SiteSetting.spam_guard_reading_sustained_adjustment,
        "no_reading" => SiteSetting.spam_guard_no_reading_adjustment,
        "confirmed_spam" => SiteSetting.spam_guard_confirmed_spam_points,
        "local_cap" => SiteSetting.spam_guard_local_points_cap,
      }
    end

    def self.settings
      {
        "version" => 5,
        "weights" => weights,
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
      local_cap = settings.fetch("weights") { weights }.fetch("local_cap")
      additional_points = [
        additional_evidence.sum { |entry| entry.fetch("points") },
        AdditionalEvidence::MAX_POINTS,
        [local_cap - local_points - engagement.fetch("adjustment"), 0].max,
      ].min
      local_points += additional_points
      if score
        decision = "watch" if external == "allow" && score >= 10
        decision = "review" if external == "silence" && score < 75
        score =
          (base + [engagement.fetch("adjustment") + local_points, local_cap].min).clamp(0, 100)
        if %w[allow watch].include?(decision)
          decision = "watch" if local_points.positive?
          decision = "review" if local_points >= LocalSignals::POSTING_CAP
        end
      end
      decision = "review" if !score && local_points >= LocalSignals::POSTING_CAP
      if %w[allow watch unknown].include?(decision) &&
           local_signals&.fetch("confirmed_spam_posts", 0).to_i.positive?
        decision = "review"
      end
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
