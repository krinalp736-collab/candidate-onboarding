class Education < ApplicationRecord
  belongs_to :candidate_profile

  enum :level, { mbo: 0, hbo: 1, bachelor: 2, master: 3, doctor: 4, course: 5 }, prefix: true
  enum :source, { manual: 0, extracted: 1 }

  validates :study, presence: true
end
