require "rails_helper"

RSpec.describe "User sessions", type: :request do
  it "logs a user in with the correct email and password" do
    create(:user, email: "jane@example.com", password: "secret123")

    post user_session_path, params: { user: { email: "jane@example.com", password: "secret123" } }

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("jane@example.com")
  end

  it "rejects the wrong password" do
    create(:user, email: "jane@example.com", password: "secret123")

    post user_session_path, params: { user: { email: "jane@example.com", password: "wrong" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Invalid email or password")
  end

  it "logs a user out" do
    user = create(:user)
    sign_in user

    delete destroy_user_session_path

    expect(response).to redirect_to(root_path)
    follow_redirect! # -> root, which now requires auth and redirects again
    expect(response).to redirect_to(new_user_session_path)
  end
end
