class WorkExperience < ApplicationRecord
  belongs_to :candidate_profile

  enum :source, { manual: 0, extracted: 1 }

  validates :job_title, presence: true
  validates :company_name, presence: true
end
