require "rails_helper"

RSpec.describe "Onboarding::Uploads", type: :request do
  let(:user) { create(:user) }

  describe "authentication" do
    it "redirects to the login page when signed out" do
      get new_onboarding_upload_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /onboarding/uploads/new" do
    before { sign_in user }

    it "renders the upload form" do
      get new_onboarding_upload_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Upload your CV")
    end

    it "redirects to the processing screen if this user already has a profile in progress" do
      profile = create(:candidate_profile, user: user)

      get new_onboarding_upload_path

      expect(response).to redirect_to(onboarding_upload_path(profile))
    end

    it "redirects to the confirmation page if this user already completed their profile" do
      profile = create(:candidate_profile, :complete_ready, user: user, onboarding_step: "completed")

      get new_onboarding_upload_path

      expect(response).to redirect_to(onboarding_profile_path(profile))
    end
  end

  describe "POST /onboarding/uploads" do
    let(:pdf) { fixture_file_upload("sample_cv.pdf", "application/pdf") }

    before { sign_in user }

    it "rejects the submission when consent isn't given" do
      expect do
        post onboarding_uploads_path, params: { candidate_profile: { file: pdf, consent: "0" } }
      end.not_to change(CandidateProfile, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("consent")
    end

    it "rejects an unsupported file type" do
      png = fixture_file_upload("not_a_cv.png", "image/png")

      expect do
        post onboarding_uploads_path, params: { candidate_profile: { file: png, consent: "1" } }
      end.not_to change(CandidateProfile, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must be a PDF, DOC, or DOCX")
    end

    it "creates a profile + document, links it to the signed-in user, enqueues parsing, and redirects to the processing screen" do
      expect do
        post onboarding_uploads_path, params: { candidate_profile: { file: pdf, consent: "1" } }
      end.to change(CandidateProfile, :count).by(1)
                                              .and change(CandidateDocument, :count).by(1)
                                              .and have_enqueued_job(ParseCandidateCvJob)

      profile = CandidateProfile.last
      expect(profile.user).to eq(user)
      expect(profile.consent_given_at).to be_present
      expect(response).to redirect_to(onboarding_upload_path(profile))
    end
  end

  describe "GET /onboarding/uploads/:access_token" do
    it "redirects to the login page when signed out" do
      profile = create(:candidate_profile, user: user)

      get onboarding_upload_path(profile)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "404s when the profile belongs to a different user" do
      other_user = create(:user)
      profile = create(:candidate_profile, user: other_user)
      sign_in user

      get onboarding_upload_path(profile)

      expect(response).to have_http_status(:not_found)
    end

    it "shows a processing state while parsing is pending" do
      profile = create(:candidate_profile, user: user)
      create(:candidate_document, candidate_profile: profile, parsing_status: :processing)
      sign_in user

      get onboarding_upload_path(profile)

      expect(response.body).to include("Analyzing your CV")
    end

    it "offers to continue to the profile once parsing has completed" do
      profile = create(:candidate_profile, user: user)
      create(:candidate_document, candidate_profile: profile, parsing_status: :completed)
      sign_in user

      get onboarding_upload_path(profile)

      expect(response.body).to include("Review my profile")
    end

    it "offers to continue manually once parsing has failed (PRD §11)" do
      profile = create(:candidate_profile, user: user)
      create(:candidate_document, candidate_profile: profile, parsing_status: :failed)
      sign_in user

      get onboarding_upload_path(profile)

      expect(response.body).to include("Continue manually")
    end
  end
end
