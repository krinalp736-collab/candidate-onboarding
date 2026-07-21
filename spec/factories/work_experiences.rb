FactoryBot.define do
  factory :work_experience do
    candidate_profile
    job_title { "Dental Assistant" }
    company_name { "Smile Clinic" }
  end
end
