require "rails_helper"

RSpec.describe CandidateProfilePrefiller do
  let(:profile) { create(:candidate_profile) }

  let(:extraction) do
    {
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      phone_number: "+31612345678",
      city: "Amsterdam",
      country: "Netherlands",
      job_function_guess: nil,
      years_of_experience: 4.7,
      professional_summary: "Experienced dental hygienist.",
      big_number: nil,
      big_status_guess: nil,
      languages: [ { name: "English", level: "native" }, { name: "Dutch", level: "B2" } ],
      education: [
        { institution: "ACTA", study: "Dental Hygiene", city_and_country: "Amsterdam, NL",
          level: "hbo", start_date: "2015-09-01", end_date: "2019-06-30", needs_review: false }
      ],
      work_experience: [
        { job_title: "Dental Hygienist", company_name: "Smile Clinic", responsibilities: "Cleanings",
          start_date: "2019-07-01", end_date: nil, current_job: true, needs_review: false }
      ],
      skills: %w[Prevention Scaling Some\ Unmatched\ Skill]
    }
  end

  it "never invents data — it only fills fields the extraction actually provided" do
    profile.first_name = nil
    described_class.call(profile, extraction.merge(first_name: nil))

    expect(profile.first_name).to be_nil
  end

  it "fills blank personal detail fields" do
    described_class.call(profile, extraction)

    expect(profile.first_name).to eq("Jane")
    expect(profile.email).to eq("jane@example.com")
  end

  it "does not overwrite a field the candidate (or a prior extraction) already filled in" do
    profile.update!(first_name: "AlreadySet")
    described_class.call(profile, extraction)

    expect(profile.first_name).to eq("AlreadySet")
  end

  it "creates languages, reusing an existing Language record by name" do
    create(:language, name: "English", code: "en")
    described_class.call(profile, extraction)

    expect(profile.candidate_languages.count).to eq(2)
    expect(Language.where(name: "English").count).to eq(1)
  end

  it "falls back to an existing Language by guessed code when the extracted (untranslated) name doesn't match by name (regression: a Dutch CV's 'Engels' guesses code 'en', colliding with the seeded 'English' record and crashing the whole prefill with RecordInvalid)" do
    english = create(:language, name: "English", code: "en")
    dutch_extraction = extraction.merge(languages: [ { name: "Engels", level: "vloeiend" } ])

    expect { described_class.call(profile, dutch_extraction) }.not_to raise_error

    expect(profile.candidate_languages.sole.language).to eq(english)
    expect(Language.where(code: "en").count).to eq(1)
  end

  it "creates education records marked source: extracted" do
    described_class.call(profile, extraction)

    education = profile.educations.sole
    expect(education.study).to eq("Dental Hygiene")
    expect(education).to be_extracted
    expect(education.needs_review).to be(false)
  end

  it "creates work experience records marked source: extracted" do
    described_class.call(profile, extraction)

    work_experience = profile.work_experiences.sole
    expect(work_experience.job_title).to eq("Dental Hygienist")
    expect(work_experience).to be_extracted
  end

  it "matches skills to the existing platform list and stores the rest as suggestions for review (PRD §3.6)" do
    matched_job_function = create(:job_function)
    profile.update!(job_function: matched_job_function)
    create(:skill, name: "Prevention", job_function: matched_job_function)
    create(:skill, name: "Scaling", job_function: matched_job_function)

    described_class.call(profile, extraction)

    matched = profile.candidate_skills.select(&:skill_id)
    unmatched = profile.candidate_skills.reject(&:skill_id)

    expect(matched.map { |cs| cs.skill.name }).to contain_exactly("Prevention", "Scaling")
    expect(unmatched.map(&:suggested_name)).to contain_exactly("Some Unmatched Skill")
  end

  it "marks an education entry needs_review when the extraction flagged it uncertain" do
    uncertain = extraction.merge(education: [ extraction[:education].first.merge(needs_review: true) ])
    described_class.call(profile, uncertain)

    expect(profile.educations.sole.needs_review).to be(true)
  end
end
