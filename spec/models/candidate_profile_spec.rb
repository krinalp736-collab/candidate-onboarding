require "rails_helper"

RSpec.describe CandidateProfile, type: :model do
  describe "onboarding_step" do
    it "defaults to cv_upload" do
      expect(described_class.new.onboarding_step).to eq("cv_upload")
    end

    it "rejects an unknown step" do
      profile = build(:candidate_profile, onboarding_step: "bogus")
      expect(profile).not_to be_valid
    end
  end

  describe "context: :complete validations (PRD §3.3 / §4 conditional logic)" do
    it "is valid when every required field and nested association is present" do
      profile = build(:candidate_profile, :complete_ready)
      expect(profile.valid?(:complete)).to be(true), profile.errors.full_messages.to_s
    end

    it "does not require any of the §3.3/§4 conditional fields outside the :complete context" do
      expect(build(:candidate_profile)).to be_valid
    end

    it "requires at least one language" do
      profile = build(:candidate_profile, :complete_ready)
      profile.candidate_languages.clear
      profile.valid?(:complete)
      expect(profile.errors[:languages]).to be_present
    end

    it "requires at least one preferred region" do
      profile = build(:candidate_profile, :complete_ready, preferred_regions_text: "")
      profile.valid?(:complete)
      expect(profile.errors[:preferred_regions]).to be_present
    end

    it "requires at least one employment type" do
      profile = build(:candidate_profile, :complete_ready, employment_types: [])
      profile.valid?(:complete)
      expect(profile.errors[:employment_types]).to be_present
    end

    it "requires at least one working day" do
      profile = build(:candidate_profile, :complete_ready, available_working_days: [])
      profile.valid?(:complete)
      expect(profile.errors[:available_working_days]).to be_present
    end

    describe "salary vs. percentage (§3.3: employed shows salary; self-employed/freelance/percentage-based shows percentage)" do
      it "requires desired_gross_salary when employment_types includes employed" do
        profile = build(:candidate_profile, :complete_ready, employment_types: [ "employed" ], desired_gross_salary: nil)
        profile.valid?(:complete)
        expect(profile.errors[:desired_gross_salary]).to be_present
      end

      it "does not require desired_gross_salary for a purely self-employed candidate" do
        profile = build(:candidate_profile, :complete_ready,
                         employment_types: [ "self_employed" ], desired_gross_salary: nil, desired_percentage: 50)
        profile.valid?(:complete)
        expect(profile.errors[:desired_gross_salary]).to be_empty
      end

      it "requires desired_percentage when employment_types includes self_employed/freelance/percentage_based" do
        profile = build(:candidate_profile, :complete_ready,
                         employment_types: [ "freelance" ], desired_gross_salary: nil, desired_percentage: nil)
        profile.valid?(:complete)
        expect(profile.errors[:desired_percentage]).to be_present
      end

      it "rejects a percentage outside 0..100" do
        profile = build(:candidate_profile, :complete_ready, employment_types: [ "freelance" ], desired_percentage: 150)
        profile.valid?(:complete)
        expect(profile.errors[:desired_percentage]).to be_present
      end
    end

    describe "BIG registration (§4: dentist/hygienist/specialist show it, assistant-type roles hide it)" do
      it "requires big_registration_status when the job function is clinical" do
        clinical = create(:job_function, :clinical)
        profile = build(:candidate_profile, :complete_ready, job_function: clinical, big_registration_status: nil)
        profile.valid?(:complete)
        expect(profile.errors[:big_registration_status]).to be_present
      end

      it "does not require big_registration_status for an assistant job function" do
        assistant = create(:job_function, clinical_group: "assistant")
        profile = build(:candidate_profile, :complete_ready, job_function: assistant, big_registration_status: nil)
        profile.valid?(:complete)
        expect(profile.errors[:big_registration_status]).to be_empty
      end

      it "requires big_number when big_registration_status is big_registered" do
        clinical = create(:job_function, :clinical)
        profile = build(:candidate_profile, :complete_ready,
                         job_function: clinical, big_registration_status: "big_registered", big_number: nil)
        profile.valid?(:complete)
        expect(profile.errors[:big_number]).to be_present
      end

      it "does not require big_number when status is not_applicable" do
        clinical = create(:job_function, :clinical)
        profile = build(:candidate_profile, :complete_ready,
                         job_function: clinical, big_registration_status: "not_applicable", big_number: nil)
        profile.valid?(:complete)
        expect(profile.errors[:big_number]).to be_empty
      end
    end
  end

  describe "#show_big_fields? / #show_average_daily_revenue_field?" do
    it "is true for a clinical job function" do
      profile = build(:candidate_profile, job_function: build(:job_function, :clinical))
      expect(profile.show_big_fields?).to be(true)
      expect(profile.show_average_daily_revenue_field?).to be(true)
    end

    it "is false with no job function selected yet" do
      profile = build(:candidate_profile, job_function: nil)
      expect(profile.show_big_fields?).to be(false)
    end
  end

  describe "#preferred_regions_text" do
    it "round-trips a comma-separated list into the underlying array column" do
      profile = build(:candidate_profile, preferred_regions_text: " Amsterdam ,Utrecht ,, Rotterdam ")
      expect(profile.preferred_regions).to eq(%w[Amsterdam Utrecht Rotterdam])
      expect(profile.preferred_regions_text).to eq("Amsterdam, Utrecht, Rotterdam")
    end
  end

  describe "#to_param" do
    it "uses the secure access_token, not the numeric id" do
      profile = create(:candidate_profile)
      expect(profile.to_param).to eq(profile.access_token)
    end
  end
end
