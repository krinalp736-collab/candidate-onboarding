# Every onboarding step requires a signed-in user. Profile lookup is scoped
# to that user's own candidate_profile (not a bare access_token match), so a
# guessed or shared link can't be used to view or edit someone else's data.
class Onboarding::BaseController < ApplicationController
  before_action :authenticate_user!

  private

  def set_profile
    @profile = current_user.candidate_profile
    raise ActiveRecord::RecordNotFound if @profile.nil? || @profile.access_token != params[:access_token]
  end
end
