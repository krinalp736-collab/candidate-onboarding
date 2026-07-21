# Maps the (already-parsed) CvExtractionService result onto a CandidateProfile
# and its nested education/work-experience/skill/language records.
#
# Only ever *fills*, never overwrites: fields the CV didn't provide come back
# null from the extraction schema and are simply skipped here, leaving them
# blank and clearly "still needs input" on the review screen, per the PRD.
class CandidateProfilePrefiller
  def self.call(candidate_profile, extraction)
    new(candidate_profile, extraction).call
  end

  def initialize(candidate_profile, extraction)
    @profile = candidate_profile
    @extraction = extraction
  end

  def call
    ActiveRecord::Base.transaction do
      fill_personal_details
      fill_job_function
      fill_summary_fields
      fill_languages
      fill_education
      fill_work_experience
      fill_skills
      profile.save!(validate: false) # partial-progress save; full validation happens on final submit
    end
  end

  private

  attr_reader :profile, :extraction

  def fill_personal_details
    profile.first_name ||= extraction[:first_name]
    profile.last_name ||= extraction[:last_name]
    profile.email ||= extraction[:email]
    profile.phone_number ||= extraction[:phone_number]
    profile.city ||= extraction[:city]
    profile.country ||= extraction[:country]
  end

  def fill_job_function
    return if profile.job_function_id.present?
    return if extraction[:job_function_guess].blank?

    match = JobFunction.where("lower(name) = ?", extraction[:job_function_guess].downcase).first
    profile.job_function = match if match
  end

  def fill_summary_fields
    profile.years_of_experience ||= extraction[:years_of_experience]&.round
    profile.professional_summary ||= extraction[:professional_summary]
    profile.big_number ||= extraction[:big_number]

    return if profile.big_registration_status.present?

    profile.big_registration_status = guess_big_status(extraction[:big_status_guess])
  end

  def guess_big_status(guess)
    return nil if guess.blank?

    case guess.downcase
    when /regist/ then "big_registered"
    when /progress/ then "in_progress"
    when /supervis/ then "under_supervision"
    end
  end

  def fill_languages
    Array(extraction[:languages]).each do |lang|
      next if lang[:name].blank?

      language = find_or_create_language(lang[:name])
      next if profile.candidate_languages.exists?(language_id: language.id)

      profile.candidate_languages.build(language: language, level: lang[:level])
    end
  end

  # The extractor is instructed not to translate CV text (see
  # CvExtractionService::SYSTEM_PROMPT), so a Dutch CV's languages come back
  # as e.g. "Engels", not "English" — that won't match the platform's
  # English-seeded Language by name. Guessing a code from the (untranslated)
  # name can then collide with an existing Language's code (both "Engels"
  # and "English" guess "en"); fall back to that existing record instead of
  # letting the uniqueness violation crash the whole parse job.
  def find_or_create_language(name)
    Language.where("lower(name) = ?", name.downcase).first ||
      Language.create!(name: name, code: name.downcase.first(2))
  rescue ActiveRecord::RecordInvalid
    Language.find_by(code: name.downcase.first(2)) || raise
  end

  def fill_education
    Array(extraction[:education]).each do |entry|
      next if entry[:study].blank? && entry[:institution].blank?

      profile.educations.build(
        institution: entry[:institution],
        study: entry[:study].presence || "Unspecified",
        city_and_country: entry[:city_and_country],
        level: normalize_education_level(entry[:level]),
        start_date: parse_date(entry[:start_date]),
        end_date: parse_date(entry[:end_date]),
        source: :extracted,
        needs_review: entry[:needs_review] || entry[:level].blank? || entry[:study].blank?
      )
    end
  end

  def fill_work_experience
    Array(extraction[:work_experience]).each do |entry|
      next if entry[:job_title].blank? && entry[:company_name].blank?

      profile.work_experiences.build(
        job_title: entry[:job_title].presence || "Unspecified",
        company_name: entry[:company_name].presence || "Unspecified",
        responsibilities: entry[:responsibilities],
        start_date: parse_date(entry[:start_date]),
        end_date: parse_date(entry[:end_date]),
        current_job: entry[:current_job] || false,
        source: :extracted,
        needs_review: entry[:needs_review] || entry[:job_title].blank? || entry[:company_name].blank?
      )
    end
  end

  def fill_skills
    Array(extraction[:skills]).each do |skill_name|
      next if skill_name.blank?

      scope = profile.job_function ? Skill.where(job_function: profile.job_function) : Skill.all
      match = scope.where("lower(name) = ?", skill_name.downcase).first

      if match
        next if profile.candidate_skills.exists?(skill_id: match.id)

        profile.candidate_skills.build(skill: match, source: :extracted)
      else
        next if profile.candidate_skills.exists?(suggested_name: skill_name)

        profile.candidate_skills.build(suggested_name: skill_name, source: :extracted)
      end
    end
  end

  def normalize_education_level(level)
    return nil if level.blank?

    Education.levels.key?(level.downcase) ? level.downcase : nil
  end

  def parse_date(value)
    return nil if value.blank?

    Date.parse(value)
  rescue Date::Error, ArgumentError, TypeError
    nil
  end
end
