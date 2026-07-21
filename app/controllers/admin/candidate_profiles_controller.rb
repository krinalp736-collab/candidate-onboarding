# PRD §12 acceptance criterion: "Admin/recruitment team can view the
# completed profile." Read-only by design — recruiters review here, they
# don't edit the candidate's own data.
class Admin::CandidateProfilesController < Admin::BaseController
  def index
    @candidate_profiles = CandidateProfile.includes(:job_function)
                                           .order(completed_at: :desc, created_at: :desc)
  end

  def show
    @candidate_profile = CandidateProfile.includes(
      :job_function, :languages, :skills, :educations, :work_experiences, :candidate_documents
    ).find(params[:id])
  end
end
