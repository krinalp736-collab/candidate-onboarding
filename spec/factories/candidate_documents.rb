FactoryBot.define do
  factory :candidate_document do
    candidate_profile
    document_type { :cv }
    parsing_status { :pending }
  end
end
