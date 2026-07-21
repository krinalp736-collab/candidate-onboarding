require "rails_helper"

RSpec.describe "User registrations", type: :request do
  it "signs a new user up and logs them in" do
    expect {
      post user_registration_path, params: { user: { email: "jane@example.com", password: "secret123", password_confirmation: "secret123" } }
    }.to change(User, :count).by(1)

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("jane@example.com")
  end

  it "re-renders the sign-up form with errors when the passwords don't match" do
    post user_registration_path, params: { user: { email: "jane@example.com", password: "secret123", password_confirmation: "nope" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Password confirmation doesn&#39;t match")
  end

  it "rejects a duplicate email" do
    create(:user, email: "jane@example.com")

    post user_registration_path, params: { user: { email: "jane@example.com", password: "secret123", password_confirmation: "secret123" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Email has already been taken")
  end
end
