class CandidateProfile < ApplicationRecord
  EMPLOYMENT_TYPES = %w[employed self_employed freelance percentage_based].freeze
  SALARY_EMPLOYMENT_TYPES = %w[employed].freeze
  PERCENTAGE_EMPLOYMENT_TYPES = %w[self_employed freelance percentage_based].freeze

  TRANSPORT_TYPES = %w[bike scooter public_transport car].freeze
  WORKING_DAYS = %w[monday tuesday wednesday thursday friday saturday sunday].freeze

  ONBOARDING_STEPS = %w[cv_upload profile_review completed].freeze

  # MySQL 5.7's JSON column type doesn't support DB-level defaults (added in
  # 8.0.13), so these are set here instead of in the migration.
  attribute :preferred_regions, default: -> { [] }
  attribute :transport_types, default: -> { [] }
  attribute :employment_types, default: -> { [] }
  attribute :available_working_days, default: -> { [] }

  has_secure_token :access_token

  belongs_to :user, optional: true
  belongs_to :job_function, optional: true

  has_many :candidate_documents, dependent: :destroy
  has_many :educations, dependent: :destroy
  has_many :work_experiences, dependent: :destroy
  has_many :candidate_skills, dependent: :destroy
  has_many :skills, through: :candidate_skills
  has_many :candidate_languages, dependent: :destroy
  has_many :languages, through: :candidate_languages

  accepts_nested_attributes_for :educations, allow_destroy: true,
                                              reject_if: ->(attrs) { attrs["study"].blank? }
  accepts_nested_attributes_for :work_experiences, allow_destroy: true,
                                                    reject_if: ->(attrs) { attrs["job_title"].blank? && attrs["company_name"].blank? }
  accepts_nested_attributes_for :candidate_skills, allow_destroy: true
  accepts_nested_attributes_for :candidate_languages, allow_destroy: true,
                                                       reject_if: ->(attrs) { attrs["language_id"].blank? }

  enum :search_status, { active: 0, passive: 1, inactive: 2 }, prefix: true
  enum :big_registration_status, {
    big_registered: 0, in_progress: 1, under_supervision: 2, not_applicable: 3
  }

  validates :onboarding_step, inclusion: { in: ONBOARDING_STEPS }

  with_options on: :complete do
    validates :consent_given_at, presence: true
    validates :first_name, :last_name, :city, :phone_number, presence: true
    validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :job_function, presence: true
    validates :max_travel_time, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :search_status, presence: true
    validates :years_of_experience, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :available_from, presence: true
    validates :desired_percentage, numericality: { in: 0..100 }, allow_nil: true

    validate :at_least_one_preferred_region
    validate :at_least_one_employment_type
    validate :at_least_one_working_day
    validate :at_least_one_language
    validate :salary_required_when_employed
    validate :percentage_required_when_percentage_based
    validate :big_registration_required_for_clinical_functions
    validate :big_number_required_when_registered
  end

  # §4 conditional-logic helpers, shared by the model and the view/Stimulus controller
  def show_big_fields?
    job_function.present? && job_function.clinical?
  end

  def show_salary_field?
    (employment_types & SALARY_EMPLOYMENT_TYPES).any?
  end

  def show_percentage_field?
    (employment_types & PERCENTAGE_EMPLOYMENT_TYPES).any?
  end

  def show_average_daily_revenue_field?
    job_function.present? && job_function.clinical?
  end

  # Onboarding URLs are unauthenticated (no login system for this MVP), so
  # route on the opaque access_token rather than the sequential id.
  def to_param = access_token

  # Preferred regions has no fixed vocabulary in the PRD (unlike transport
  # types / employment types / working days), so the form exposes it as a
  # plain comma-separated text field rather than a fixed checkbox list.
  def preferred_regions_text
    preferred_regions.join(", ")
  end

  def preferred_regions_text=(value)
    self.preferred_regions = value.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  # The edit form submits a hidden `candidate_profile[employment_types][]`
  # (value "") alongside the checkboxes so unchecking every box still sends
  # the key (otherwise the param is dropped entirely and the previous
  # selection would silently survive). Reject the blank so an all-unchecked
  # submission actually clears the attribute instead of leaving `[""]`,
  # which `Array#blank?` treats as present.
  def employment_types=(values)
    super(Array(values).reject(&:blank?))
  end

  def available_working_days=(values)
    super(Array(values).reject(&:blank?))
  end

  private

  def at_least_one_preferred_region
    errors.add(:preferred_regions, "must include at least one region") if preferred_regions.blank?
  end

  def at_least_one_employment_type
    errors.add(:employment_types, "must include at least one option") if employment_types.blank?
  end

  def at_least_one_working_day
    errors.add(:available_working_days, "must include at least one day") if available_working_days.blank?
  end

  def at_least_one_language
    errors.add(:languages, "must include at least one language") if candidate_languages.reject(&:marked_for_destruction?).empty?
  end

  def salary_required_when_employed
    return unless show_salary_field?

    errors.add(:desired_gross_salary, "is required for employed roles") if desired_gross_salary.blank?
  end

  def percentage_required_when_percentage_based
    return unless show_percentage_field?

    errors.add(:desired_percentage, "is required for self-employed/percentage-based roles") if desired_percentage.blank?
  end

  def big_registration_required_for_clinical_functions
    return unless show_big_fields?

    errors.add(:big_registration_status, "is required for this job function") if big_registration_status.blank?
  end

  def big_number_required_when_registered
    return unless big_registration_status == "big_registered"

    errors.add(:big_number, "is required when BIG registered") if big_number.blank?
  end
end
