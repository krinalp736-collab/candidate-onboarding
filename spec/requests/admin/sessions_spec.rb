require "rails_helper"

RSpec.describe "Admin sessions", type: :request do
  it "logs an admin in with the correct email and password and redirects to the admin dashboard" do
    admin_user = create(:admin_user, email: "admin@example.com", password: "secret123")

    post admin_user_session_path, params: { admin_user: { email: "admin@example.com", password: "secret123" } }

    expect(response).to redirect_to(admin_root_path)
    follow_redirect!
    expect(response.body).to include("admin@example.com")
  end

  it "rejects the wrong password and re-renders the login form" do
    create(:admin_user, email: "admin@example.com", password: "secret123")

    post admin_user_session_path, params: { admin_user: { email: "admin@example.com", password: "wrong" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Invalid email or password")
  end

  it "has no sign-up route (admins can't self-register — PRD §9/§12)" do
    expect { new_admin_user_registration_path }.to raise_error(NameError)
  end

  it "logs an admin out" do
    admin_user = create(:admin_user)
    sign_in admin_user

    delete destroy_admin_user_session_path

    expect(response).to redirect_to(root_path)

    get admin_candidate_profiles_path
    expect(response).to redirect_to(new_admin_user_session_path)
  end
end
