require "rails_helper"

RSpec.describe "Onboarding::Profiles", type: :request do
  let(:job_function) { create(:job_function, name: "General dentist", clinical_group: "dentist") }
  let(:user) { create(:user) }
  let(:profile) { create(:candidate_profile, job_function: job_function, user: user) }

  before { sign_in user }

  describe "authentication/authorization" do
    it "redirects to the login page when signed out" do
      sign_out user

      get edit_onboarding_profile_path(profile)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "404s when the profile belongs to a different user" do
      other_profile = create(:candidate_profile, user: create(:user))

      get edit_onboarding_profile_path(other_profile)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /onboarding/profiles/:access_token/edit" do
    it "renders the review form, prefilled where data already exists" do
      profile.update!(first_name: "Jane")

      get edit_onboarding_profile_path(profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Jane")
    end

    it "renders the BIG registration fields for a clinical job function (PRD §4)" do
      get edit_onboarding_profile_path(profile)
      expect(response.body).to include("BIG registration status")
    end

    it "marks extracted-but-uncertain records for review" do
      create(:education, candidate_profile: profile, source: :extracted, needs_review: true)

      get edit_onboarding_profile_path(profile)

      expect(response.body).to include("Please check")
    end

    it "styles textareas with form-control, not just text/select fields (regression: text_area is aliased separately from :textarea in Rails' FormBuilder)" do
      get edit_onboarding_profile_path(profile)

      expect(response.body).to match(
        %r{<textarea(?=[^>]*name="candidate_profile\[professional_summary\]")(?=[^>]*class="[^"]*\bform-control\b)[^>]*>}
      )
    end
  end

  describe "PATCH /onboarding/profiles/:access_token" do
    let(:language) { create(:language) }
    let(:valid_params) do
      {
        candidate_profile: {
          first_name: "Jane", last_name: "Doe", email: "jane@example.com",
          phone_number: "0612345678", city: "Amsterdam",
          job_function_id: job_function.id,
          preferred_regions_text: "Amsterdam", max_travel_time: "20",
          employment_types: [ "employed" ], desired_gross_salary: "3000",
          big_registration_status: "not_applicable",
          search_status: "active", years_of_experience: "3",
          available_working_days: %w[monday tuesday], available_from: Date.tomorrow.to_s,
          language_ids: [ language.id.to_s ], language_levels: { language.id.to_s => "native" }
        }
      }
    end

    before { profile.update!(consent_given_at: Time.current) }

    it "saves the profile and redirects to the confirmation page when everything required is present" do
      patch onboarding_profile_path(profile), params: valid_params

      expect(response).to redirect_to(onboarding_profile_path(profile))
      profile.reload
      expect(profile.onboarding_step).to eq("completed")
      expect(profile.completed_at).to be_present
      expect(profile.languages.pluck(:id)).to eq([ language.id ])
      expect(profile.candidate_languages.first.level).to eq("native")
    end

    it "notifies the recruitment team once the profile is completed (PRD §10)" do
      expect { patch onboarding_profile_path(profile), params: valid_params }
        .to have_enqueued_job.on_queue("default").at_least(:once)
    end

    it "re-renders the form with errors and does not mark the step completed when required fields are missing" do
      patch onboarding_profile_path(profile), params: { candidate_profile: { first_name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(profile.reload.onboarding_step).to eq("cv_upload")
    end

    it "marks invalid fields with Bootstrap's is-invalid class and shows the error message inline" do
      patch onboarding_profile_path(profile), params: { candidate_profile: { first_name: "" } }

      expect(response.body).to match(
        %r{<input(?=[^>]*name="candidate_profile\[first_name\]")(?=[^>]*class="[^"]*\bis-invalid\b)[^>]*>}
      )
      expect(response.body).to include('class="invalid-feedback"')
      expect(response.body).to include("First name can&#39;t be blank")
    end

    it "marks a belongs_to select as invalid via the association's error, not the foreign key (regression: job_function_id has no error of its own, job_function does)" do
      patch onboarding_profile_path(profile), params: { candidate_profile: { job_function_id: "" } }

      expect(response.body).to match(
        %r{<select(?=[^>]*name="candidate_profile\[job_function_id\]")(?=[^>]*class="[^"]*\bis-invalid\b)[^>]*>}
      )
      expect(response.body).to include("Job function can&#39;t be blank")
    end

    it "marks preferred_regions_text as invalid via the underlying preferred_regions error (regression: writer accessor doesn't share the model's error key)" do
      patch onboarding_profile_path(profile), params: { candidate_profile: { preferred_regions_text: "" } }

      expect(response.body).to match(
        %r{<input(?=[^>]*name="candidate_profile\[preferred_regions_text\]")(?=[^>]*class="[^"]*\bis-invalid\b)[^>]*>}
      )
      expect(response.body).to include("Preferred regions must include at least one region")
    end

    it "shows a red border and inline message for checkbox-group fields built outside the form builder (regression: raw check_box_tag groups got no error styling at all)" do
      patch onboarding_profile_path(profile), params: { candidate_profile: { employment_types: [], available_working_days: [], language_ids: [] } }

      expect(response.body).to include("border-danger")
      expect(response.body).to include("Employment types must include at least one option")
      expect(response.body).to include("Available working days must include at least one day")
      expect(response.body).to include("Languages must include at least one language")
    end

    it "stores unmatched free-text skills for recruiter review (PRD §3.6)" do
      params = valid_params.deep_merge(candidate_profile: { other_skills_text: "Laser dentistry, CBCT imaging" })

      patch onboarding_profile_path(profile), params: params

      suggested = profile.reload.candidate_skills.map(&:suggested_name).compact
      expect(suggested).to contain_exactly("Laser dentistry", "CBCT imaging")
    end
  end
end
