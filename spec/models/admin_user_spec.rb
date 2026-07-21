require "rails_helper"

RSpec.describe AdminUser, type: :model do
  it "authenticates with the correct password" do
    admin_user = create(:admin_user, password: "secret123")

    expect(admin_user.valid_password?("secret123")).to be true
  end

  it "does not authenticate with the wrong password" do
    admin_user = create(:admin_user, password: "secret123")

    expect(admin_user.valid_password?("wrong")).to be false
  end

  it "requires a unique email" do
    create(:admin_user, email: "admin@example.com")
    duplicate = build(:admin_user, email: "admin@example.com")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to be_present
  end

  it "has no registerable module, so admins can't self sign up (PRD §9/§12: only authorized recruiters may view profiles)" do
    expect(AdminUser.devise_modules).not_to include(:registerable)
  end
end
