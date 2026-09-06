# frozen_string_literal: true

RSpec.describe Admin::SiteSettingsController do
  fab!(:admin)

  it "exposes the scoring defaults, bounds and descriptions in admin settings" do
    sign_in(admin)
    get "/admin/site_settings.json"
    expect(response.status).to eq(200)
    settings = response.parsed_body.fetch("site_settings").index_by { |setting| setting["setting"] }
    {
      "spam_guard_reading_limited_adjustment" => [-5, -100, 0],
      "spam_guard_reading_meaningful_adjustment" => [-10, -100, 0],
      "spam_guard_reading_sustained_adjustment" => [-15, -100, 0],
      "spam_guard_no_reading_adjustment" => [10, 0, 100],
      "spam_guard_confirmed_spam_points" => [85, 0, 100],
      "spam_guard_local_points_cap" => [100, 0, 100],
      "spam_guard_external_weak_points" => [20, 0, 100],
      "spam_guard_email_moderate_points" => [50, 0, 100],
      "spam_guard_email_strong_points" => [85, 0, 100],
      "spam_guard_ip_moderate_points" => [30, 0, 100],
      "spam_guard_ip_strong_points" => [50, 0, 100],
      "spam_guard_external_combined_points" => [90, 0, 100],
      "spam_guard_email_moderate_confidence" => [50, 0, 100],
      "spam_guard_ip_moderate_confidence" => [50, 0, 100],
      "spam_guard_email_moderate_frequency" => [3, 1, 10_000],
      "spam_guard_ip_moderate_frequency" => [5, 1, 10_000],
    }.each do |name, (default, minimum, maximum)|
      setting = settings.fetch(name)
      expect(setting["default"].to_i).to eq(default)
      expect(setting["description"]).to be_present
      expect(setting["min"]).to eq(minimum)
      expect(setting["max"]).to eq(maximum)
    end
  end
end
