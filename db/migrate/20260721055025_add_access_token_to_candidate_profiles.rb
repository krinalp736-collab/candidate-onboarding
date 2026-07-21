class AddAccessTokenToCandidateProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :candidate_profiles, :access_token, :string
    add_index :candidate_profiles, :access_token, unique: true
  end
end
