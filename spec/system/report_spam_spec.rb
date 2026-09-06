# frozen_string_literal: true

RSpec.describe "Report spam with lookups disabled" do
  fab!(:admin)
  fab!(:user)
  fab!(:spam_post) { Fabricate(:spam_guard_confirmed_post, user: user) }

  it "keeps the real admin connector and confirmation dialog available" do
    SiteSetting.spam_guard_enabled = false
    SiteSetting.spam_guard_submissions_enabled = true
    SiteSetting.spam_guard_submission_api_key = "private-test-key"
    sign_in(admin)

    visit "/admin/users/#{user.id}/#{user.username}"
    find(".spam-guard-user__toggle").click
    expect(page).to have_css(".spam-guard-submission__preview")
    find(".spam-guard-submission__preview").click
    expect(page).to have_css(".spam-guard-submission-confirmation", text: user.email)
    expect(page).to have_css(".spam-guard-submission-confirmation__evidence", text: spam_post.raw)
    find(".spam-guard-submission-confirmation__cancel").click
    expect(page).to have_no_css(".spam-guard-submission-confirmation")
    expect(DiscourseSpamGuard::Submission.where(user_id: user.id)).to be_empty
    expect(DiscourseSpamGuard::Scan.where(user_id: user.id)).to be_empty
  end
end
