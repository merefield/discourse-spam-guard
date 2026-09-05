# frozen_string_literal: true

RSpec.describe "Configure Spam Guard risk weights" do
  fab!(:admin)
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

  before { sign_in(admin) }

  it "lets an admin find and save the per-post weight and reading adjustments" do
    settings_page.visit_filtered_plugin_setting("spam_guard")
    %w[
      reading_limited_adjustment
      reading_meaningful_adjustment
      reading_sustained_adjustment
      no_reading_adjustment
      confirmed_spam_points
      local_points_cap
    ].each { |suffix| expect(settings_page).to have_setting("spam_guard_#{suffix}") }
    expect(settings_page.find_setting("spam_guard_confirmed_spam_points")).to have_text(
      "Risk points per distinct post",
    )
    expect(settings_page.find_setting("spam_guard_reading_sustained_adjustment")).to have_text(
      "Negative values reduce concern",
    )
    settings_page.fill_setting("spam_guard_confirmed_spam_points", "75")
    settings_page.save_setting("spam_guard_confirmed_spam_points")
    expect(settings_page).to have_overridden_setting(
      "spam_guard_confirmed_spam_points",
      value: "75",
    )
    page.refresh
    expect(settings_page).to have_overridden_setting(
      "spam_guard_confirmed_spam_points",
      value: "75",
    )
  end
end
