FactoryBot.define do
  factory :candidate_profile do
    onboarding_step { "cv_upload" }

    trait :complete_ready do
      first_name { "Jane" }
      last_name { "Doe" }
      email { "jane@example.com" }
      phone_number { "+31 6 12345678" }
      city { "Amsterdam" }
      country { "Netherlands" }
      job_function { association(:job_function) }
      preferred_regions_text { "Amsterdam, Utrecht" }
      max_travel_time { 30 }
      employment_types { [ "employed" ] }
      desired_gross_salary { 3500 }
      search_status { "active" }
      years_of_experience { 5 }
      available_working_days { %w[monday tuesday wednesday] }
      available_from { Date.tomorrow }
      consent_given_at { Time.current }

      after(:build) do |profile|
        language = Language.first || FactoryBot.create(:language)
        profile.candidate_languages.build(language: language, level: "fluent")
      end
    end
  end
end
