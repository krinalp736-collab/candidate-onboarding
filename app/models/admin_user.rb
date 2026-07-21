# Recruiter/admin accounts, provisioned via db/seeds.rb or the Rails console —
# deliberately no :registerable. Self-serve admin sign-up would let anyone
# grant themselves access to every candidate's profile and CV (PRD §9/§12).
class AdminUser < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable
end
