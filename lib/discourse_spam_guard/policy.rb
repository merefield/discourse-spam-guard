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

    def self.external_weights
      {
        "external_weak_points" => SiteSetting.spam_guard_external_weak_points,
        "email_moderate_points" => SiteSetting.spam_guard_email_moderate_points,
        "email_strong_points" => SiteSetting.spam_guard_email_strong_points,
        "ip_moderate_points" => SiteSetting.spam_guard_ip_moderate_points,
        "ip_strong_points" => SiteSetting.spam_guard_ip_strong_points,
        "external_combined_points" => SiteSetting.spam_guard_external_combined_points,
        "email_moderate_confidence" => SiteSetting.spam_guard_email_moderate_confidence,
        "email_moderate_frequency" => SiteSetting.spam_guard_email_moderate_frequency,
        "ip_moderate_confidence" => SiteSetting.spam_guard_ip_moderate_confidence,
        "ip_moderate_frequency" => SiteSetting.spam_guard_ip_moderate_frequency,
      }
    end

    def self.settings
      {
        "version" => 6,
        "weights" => weights,
        "external_weights" => external_weights,
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
      external_scoring = score_external(evidence, settings) if status == "checked"
      base = external_scoring&.fetch("score")
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
        # Configurable display weights must not relax automatic-silencing safeguards.
        decision = "review" if external == "silence" && engagement.fetch("adjustment") < -5
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
        "external_scoring" => external_scoring,
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

    def self.qualifies?(data, field, settings, moderate: false)
      return false unless data && data["appears"] && !data["blacklisted"]
      return false unless data["last_seen"] && !data["confidence"].nil?

      seen = Time.zone.parse(data["last_seen"])
      return false unless seen && seen <= Time.current && seen >= settings["max_age_days"].days.ago

      thresholds = moderate ? settings.fetch("external_weights") { external_weights } : settings
      prefix = moderate ? "#{field}_moderate" : field
      data["frequency"] >= thresholds.fetch("#{prefix}_frequency") &&
        data["confidence"].to_f >= thresholds.fetch("#{prefix}_confidence")
    end

    def self.score_external(evidence, settings)
      weights = settings.fetch("external_weights") { external_weights }
      fields = evidence.transform_values { |data| data["appears"] || data["blacklisted"] }
      scores = fields.transform_values { |matched| matched ? weights["external_weak_points"] : 0 }
      tiers = fields.transform_values { |matched| matched ? "weak" : "none" }
      %w[email ip].each do |field|
        strong = qualifies?(evidence[field], field, settings)
        moderate = qualifies?(evidence[field], field, settings, moderate: true)
        next unless strong || moderate

        tiers[field] = strong ? "strong" : "moderate"
        candidates = [scores[field], weights.fetch("#{field}_moderate_points")]
        candidates << weights.fetch("#{field}_strong_points") if strong
        scores[field] = candidates.max
      end
      combined = tiers["email"] == "strong" && tiers["ip"] == "strong"
      score = (scores.values + [combined ? weights["external_combined_points"] : 0]).max
      { "score" => score, "tiers" => tiers, "points" => scores, "combined" => combined }
    end

    def self.evaluate(evidence, settings = self.settings)
      strong = %w[email ip].select { |field| qualifies?(evidence[field], field, settings) }
      if strong.include?("email") && (settings["preset"] == "balanced" || strong.include?("ip"))
        "silence"
      elsif strong.any? || qualifies?(evidence["email"], "email", settings, moderate: true)
        "review"
      elsif evidence.values.any? { |data| data["appears"] || data["blacklisted"] }
        "watch"
      else
        "allow"
      end
    end
  end
end
