# Step 2 of the onboarding wizard (PRD §2, §7.2): review/complete the
# prefilled profile, with conditional fields (§4) and repeaters for
# education/work experience.
class Onboarding::ProfilesController < Onboarding::BaseController
  before_action :set_profile
  before_action :load_reference_data

  def edit
  end

  def show
  end

  def update
    @profile.assign_attributes(profile_params)
    apply_language_levels
    apply_other_skills

    if @profile.save(context: :complete)
      @profile.update_columns(onboarding_step: "completed", completed_at: Time.current)
      RecruitmentMailer.candidate_onboarding_completed(@profile).deliver_later
      redirect_to onboarding_profile_path(@profile), notice: "Profile saved successfully."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def load_reference_data
    @job_functions = JobFunction.active.ordered
    @languages = Language.ordered
    @skills_by_job_function = Skill.ordered.group_by(&:job_function_id)
  end

  def profile_params
    params.require(:candidate_profile).permit(
      :first_name, :last_name, :email, :phone_number, :city, :country,
      :job_function_id, :max_travel_time, :search_status, :reason_for_looking,
      :desired_gross_salary, :desired_percentage, :average_daily_revenue,
      :big_registration_status, :big_number, :years_of_experience,
      :available_from, :notice_period, :motivation, :internal_notes, :professional_summary,
      :preferred_regions_text,
      transport_types: [], employment_types: [], available_working_days: [],
      language_ids: [], skill_ids: [],
      educations_attributes: %i[id institution study city_and_country level start_date end_date _destroy],
      work_experiences_attributes: %i[id job_title company_name responsibilities start_date end_date current_job _destroy]
    )
  end

  # Language *selection* comes through the through-association's built-in
  # `language_ids=` setter (permitted above); the per-language proficiency
  # level is a small side-channel hash keyed by language id, applied here.
  def apply_language_levels
    levels = params.dig(:candidate_profile, :language_levels) || {}

    @profile.candidate_languages.each do |candidate_language|
      level = levels[candidate_language.language_id.to_s]
      candidate_language.level = level if level.present?
    end
  end

  # Platform-matched skills go through `skill_ids=`; anything the candidate
  # types that isn't on the list is stored as a free-text suggestion for
  # recruiter review (PRD §3.6).
  def apply_other_skills
    text = params.dig(:candidate_profile, :other_skills_text)
    return if text.blank?

    existing_names = @profile.candidate_skills.map { |cs| cs.display_name&.downcase }

    text.split(",").map(&:strip).reject(&:blank?).each do |name|
      next if existing_names.include?(name.downcase)

      @profile.candidate_skills.build(suggested_name: name, source: :manual)
      existing_names << name.downcase
    end
  end
end
