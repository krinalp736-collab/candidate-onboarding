# Step 1 of the onboarding wizard (PRD §2, §7.1): CV upload + consent, then
# hand off to ParseCandidateCvJob and show a processing state until it's done.
class Onboarding::UploadsController < Onboarding::BaseController
  before_action :set_profile, only: %i[show]
  before_action :redirect_to_existing_profile, only: %i[new create]

  def new
    @profile = CandidateProfile.new
  end

  def create
    @profile = CandidateProfile.new(onboarding_step: "cv_upload", user: current_user)

    unless consent_given?
      @profile.errors.add(:consent_given_at, "must be accepted before uploading")
      return render :new, status: :unprocessable_content
    end

    document = @profile.candidate_documents.build(document_type: :cv)
    document.file.attach(params[:candidate_profile][:file]) if params.dig(:candidate_profile, :file).present?

    if document.valid?(:upload) && document.file.attached?
      @profile.consent_given_at = Time.current
      @profile.save!(validate: false) # cascades to persist the already-validated `document` via autosave
      ParseCandidateCvJob.perform_later(document.id)
      redirect_to onboarding_upload_path(@profile)
    else
      @profile.errors.merge!(document.errors)
      render :new, status: :unprocessable_content
    end
  end

  # Processing/loading screen — polls until the background job finishes, then
  # moves on to the profile review step (PRD: loading state + "continue
  # manually" if parsing fails).
  def show
    @document = @profile.candidate_documents.order(:created_at).last
  end

  private

  # A user can only ever have one candidate_profile (has_one); without this,
  # a signed-in user revisiting the upload form could create a second one.
  def redirect_to_existing_profile
    profile = current_user.candidate_profile
    return unless profile

    redirect_to(profile.onboarding_step == "completed" ? onboarding_profile_path(profile) : onboarding_upload_path(profile))
  end

  def consent_given?
    ActiveModel::Type::Boolean.new.cast(params.dig(:candidate_profile, :consent))
  end
end
