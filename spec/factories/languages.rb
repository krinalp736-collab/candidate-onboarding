FactoryBot.define do
  factory :language do
    name { "English" }
    sequence(:code) { |n| "l#{n}" }
  end
end
