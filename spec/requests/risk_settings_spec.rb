# frozen_string_literal: true

RSpec.describe Admin::SiteSettingsController do
  fab!(:admin)

  it "exposes the scoring defaults, bounds and descriptions in admin settings" do
    sign_in(admin)
    get "/admin/site_settings.json"
    expect(response.status).to eq(200)
    settings = response.parsed_body.fetch("site_settings").index_by { |setting| setting["setting"] }
    {
      "spam_guard_reading_limited_adjustment" => -5,
      "spam_guard_reading_meaningful_adjustment" => -10,
      "spam_guard_reading_sustained_adjustment" => -15,
      "spam_guard_no_reading_adjustment" => 10,
      "spam_guard_confirmed_spam_points" => 85,
      "spam_guard_local_points_cap" => 100,
      "spam_guard_external_weak_points" => 20,
      "spam_guard_email_moderate_points" => 50,
      "spam_guard_email_strong_points" => 85,
      "spam_guard_ip_moderate_points" => 30,
      "spam_guard_ip_strong_points" => 50,
      "spam_guard_external_combined_points" => 90,
      "spam_guard_email_moderate_confidence" => 50,
      "spam_guard_ip_moderate_confidence" => 50,
    }.each do |name, default|
      setting = settings.fetch(name)
      expect(setting["default"].to_i).to eq(default)
      expect(setting["description"]).to be_present
      expect(setting["min"]).to eq(default.negative? ? -100 : 0)
      expect(setting["max"]).to eq(default.negative? ? 0 : 100)
    end
  end
end
