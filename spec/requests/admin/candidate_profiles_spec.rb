require "rails_helper"

RSpec.describe "Admin::CandidateProfiles", type: :request do
  describe "authentication (PRD §9: only authorized admins may view profiles)" do
    it "redirects to the admin login page when signed out" do
      get admin_candidate_profiles_path

      expect(response).to redirect_to(new_admin_user_session_path)
    end

    it "allows access once signed in as an admin user" do
      sign_in create(:admin_user)

      get admin_candidate_profiles_path

      expect(response).to have_http_status(:ok)
    end

    it "does not allow a regular user to access the admin area" do
      sign_in create(:user)

      get admin_candidate_profiles_path

      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "GET /admin/candidate_profiles" do
    before { sign_in create(:admin_user) }

    it "lists candidate profiles" do
      profile = create(:candidate_profile, :complete_ready, first_name: "Jane", last_name: "Doe")

      get admin_candidate_profiles_path

      expect(response.body).to include("Jane Doe")
      expect(response.body).to include(profile.job_function.name)
    end

    it "shows a friendly empty state when there are no candidates" do
      get admin_candidate_profiles_path

      expect(response.body).to include("No candidates yet")
    end
  end

  describe "GET /admin/candidate_profiles/:id" do
    before { sign_in create(:admin_user) }

    it "shows the full profile, including education, work experience, and skills" do
      profile = create(:candidate_profile, :complete_ready, first_name: "Jane", last_name: "Doe")
      create(:education, candidate_profile: profile, study: "Dentistry", institution: "ACTA")
      create(:work_experience, candidate_profile: profile, job_title: "Hygienist", company_name: "Smile Clinic")
      create(:candidate_skill, candidate_profile: profile, skill: create(:skill, name: "Prevention"))

      get admin_candidate_profile_path(id: profile.id)

      expect(response.body).to include("Jane Doe")
      expect(response.body).to include("Dentistry")
      expect(response.body).to include("ACTA")
      expect(response.body).to include("Hygienist")
      expect(response.body).to include("Prevention")
    end

    it "offers a download link for an attached CV" do
      profile = create(:candidate_profile)
      document = create(:candidate_document, candidate_profile: profile)
      document.file.attach(io: StringIO.new("fake"), filename: "cv.pdf", content_type: "application/pdf")

      get admin_candidate_profile_path(id: profile.id)

      expect(response.body).to include("Download")
    end

    it "only shows conditional fields (BIG/revenue/salary/percentage) that actually apply" do
      assistant = create(:job_function, clinical_group: "assistant")
      profile = create(:candidate_profile, :complete_ready, job_function: assistant, employment_types: [ "self_employed" ], desired_percentage: 40)

      get admin_candidate_profile_path(id: profile.id)

      expect(response.body).not_to include("BIG registration")
      expect(response.body).to include("Desired percentage")
    end
  end
end
