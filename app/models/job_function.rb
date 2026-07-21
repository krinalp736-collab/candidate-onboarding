class JobFunction < ApplicationRecord
  CLINICAL_GROUPS = %w[dentist assistant front_office practice_manager technician].freeze

  has_many :skills, dependent: :destroy
  has_many :candidate_profiles, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :clinical_group, inclusion: { in: CLINICAL_GROUPS }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  # §4: dentist/hygienist/specialist show BIG registration + revenue fields;
  # assistants/front-office/practice-managers/technicians hide them.
  def clinical? = clinical_group == "dentist"
end
