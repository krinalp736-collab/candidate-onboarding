FactoryBot.define do
  factory :education do
    candidate_profile
    study { "Dentistry" }
    institution { "ACTA" }
  end
end
