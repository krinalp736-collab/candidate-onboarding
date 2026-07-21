# PRD §9/§12: only authorized admins/recruiters may view submitted profiles
# and CVs. AdminUser accounts are provisioned via db/seeds.rb or the Rails
# console (no self-registration — see AdminUser for why).
class Admin::BaseController < ApplicationController
  before_action :authenticate_admin_user!
end
