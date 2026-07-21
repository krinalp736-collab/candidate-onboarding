class CreateCandidateSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :candidate_skills do |t|
      t.references :candidate_profile, null: false, foreign_key: true
      # Nullable: an extracted skill that doesn't match the platform's Skill
      # list is stored via suggested_name instead, for recruiter review.
      t.references :skill, null: true, foreign_key: true
      t.string :suggested_name
      t.integer :source, null: false, default: 0 # enum: manual | extracted

      t.timestamps
    end

    add_index :candidate_skills, [ :candidate_profile_id, :skill_id ], unique: true
  end
end
