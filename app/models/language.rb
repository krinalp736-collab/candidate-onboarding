class Language < ApplicationRecord
  has_many :candidate_languages, dependent: :destroy
  has_many :candidate_profiles, through: :candidate_languages

  validates :name, presence: true
  validates :code, presence: true, uniqueness: true

  scope :ordered, -> { order(:name) }
end
