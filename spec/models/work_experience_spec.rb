require "rails_helper"

RSpec.describe WorkExperience, type: :model do
  it "requires a job title" do
    expect(build(:work_experience, job_title: nil)).not_to be_valid
  end

  it "requires a company name" do
    expect(build(:work_experience, company_name: nil)).not_to be_valid
  end

  it "PRD §3.5: supports more than one work experience per profile" do
    profile = create(:candidate_profile)
    create(:work_experience, candidate_profile: profile, job_title: "A", company_name: "X")
    create(:work_experience, candidate_profile: profile, job_title: "B", company_name: "Y")

    expect(profile.work_experiences.count).to eq(2)
  end
end
