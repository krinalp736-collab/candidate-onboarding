class CandidateLanguage < ApplicationRecord
  belongs_to :candidate_profile
  belongs_to :language

  validates :language_id, uniqueness: { scope: :candidate_profile_id }
end
