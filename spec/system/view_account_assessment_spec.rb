# frozen_string_literal: true

RSpec.describe "View saved Spam Guard calculation" do
  fab!(:admin)
  fab!(:user)

  it "separates arithmetic and evidence and retains the result after settings change" do
    evidence = {
      "email" => {
        "appears" => true,
        "frequency" => 3,
        "confidence" => 40,
        "last_seen" => 2.days.ago.iso8601,
      },
      "ip" => {
        "appears" => true,
        "frequency" => 5,
        "confidence" => 52.63,
        "last_seen" => 5.days.ago.iso8601,
      },
    }
    policy = DiscourseSpamGuard::Policy.settings
    policy["assessment"] = DiscourseSpamGuard::Policy.assess(
      evidence,
      policy,
      engagement: {
        "adjustment" => 10,
        "available" => true,
        "level" => "none",
        "topics_viewed" => 0,
        "posts_read" => 0,
        "reading_seconds" => 0,
        "days_visited" => 0,
      },
      status: "checked",
    )
    DiscourseSpamGuard::Scan.create!(
      user: user,
      status: "checked",
      decision: "watch",
      source: "manual",
      evidence: evidence,
      policy: policy,
    )
    SiteSetting.spam_guard_email_report_points = 100
    sign_in(admin)

    visit "/admin/users/#{user.id}/#{user.username}"
    find(".spam-guard-user__toggle").click
    expect(page).to have_css(".spam-guard-risk-score__value", text: "49%")
    expect(page).to have_css(".spam-guard-evidence__summary", text: "24 points")
    expect(page).to have_css(".spam-guard-calculation", text: "3 reports × 8")
    expect(page).to have_css(
      ".spam-guard-evidence__body .spam-guard-evidence__provider",
      text: "52.63",
    )
    find(".spam-guard-evidence__help summary").click
    expect(page).to have_css(".spam-guard-evidence__help", text: "Counts are cumulative")
    page.refresh
    find(".spam-guard-user__toggle").click
    expect(page).to have_css(".spam-guard-calculation__total", text: "49%")
  end
end
