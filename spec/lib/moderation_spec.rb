# frozen_string_literal: true

RSpec.describe DiscourseSpamGuard::Moderation do
  describe ".allow" do
    fab!(:user)
    fab!(:admin)

    it "rejects non-staff actors without creating an exception" do
      actor = Fabricate(:user)

      expect { described_class.allow(user, actor) }.to raise_error(Discourse::InvalidAccess)
      expect(DiscourseSpamGuard::Account.where(user: user)).to be_empty
    end

    it "protects staff accounts" do
      expect { described_class.allow(admin, admin) }.to raise_error(Discourse::InvalidAccess)
      expect(DiscourseSpamGuard::Account.where(user: admin)).to be_empty
    end
  end
end
