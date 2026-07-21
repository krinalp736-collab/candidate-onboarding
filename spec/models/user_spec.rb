require "rails_helper"

RSpec.describe User, type: :model do
  it "authenticates with the correct password" do
    user = create(:user, password: "secret123")

    expect(user.valid_password?("secret123")).to be true
  end

  it "requires a unique email" do
    create(:user, email: "jane@example.com")
    duplicate = build(:user, email: "jane@example.com")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to be_present
  end

  it "supports self sign up" do
    expect(User.devise_modules).to include(:registerable)
  end

  it "destroys its candidate_profile when the user is destroyed" do
    user = create(:user)
    profile = create(:candidate_profile, user: user)

    expect { user.destroy }.to change(CandidateProfile, :count).by(-1)
    expect(CandidateProfile.exists?(profile.id)).to be false
  end
end
