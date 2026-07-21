# PRD §10: notify the admin/recruitment team once onboarding completes.
class RecruitmentMailer < ApplicationMailer
  def candidate_onboarding_completed(candidate_profile)
    @profile = candidate_profile
    recipient = ENV["RECRUITMENT_TEAM_EMAIL"] || "recruitment@example.com"

    mail(to: recipient, subject: "New candidate profile: #{@profile.first_name} #{@profile.last_name}".strip)
  end
end
