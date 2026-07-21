class CandidateSkill < ApplicationRecord
  belongs_to :candidate_profile
  belongs_to :skill, optional: true

  enum :source, { manual: 0, extracted: 1 }

  validates :skill_id, uniqueness: { scope: :candidate_profile_id }, allow_nil: true
  validate :skill_or_suggested_name_present

  # A matched platform Skill, or the free-text name for a recruiter to review
  # when the CV parser found a skill that doesn't map to the platform list.
  def display_name
    skill&.name || suggested_name
  end

  private

  def skill_or_suggested_name_present
    return if skill_id.present? || suggested_name.present?

    errors.add(:base, "must reference a skill or provide a suggested name")
  end
end
