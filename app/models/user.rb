class User < ApplicationRecord
  # :validatable already covers email presence/uniqueness/format (see
  # config.email_regexp in config/initializers/devise.rb for the format used)
  # and password presence/length — don't duplicate those checks here.
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one :candidate_profile, dependent: :destroy
end
