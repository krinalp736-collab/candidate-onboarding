FactoryBot.define do
  factory :job_function do
    sequence(:name) { |n| "Job Function #{n}" }
    clinical_group { "assistant" }
    active { true }

    trait :clinical do
      clinical_group { "dentist" }
    end
  end
end
