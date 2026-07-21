class CreateCandidateLanguages < ActiveRecord::Migration[8.1]
  def change
    create_table :candidate_languages do |t|
      t.references :candidate_profile, null: false, foreign_key: true
      t.references :language, null: false, foreign_key: true
      t.string :level # e.g. B2, fluent, native — free text per PRD

      t.timestamps
    end

    add_index :candidate_languages, [ :candidate_profile_id, :language_id ], unique: true
  end
end
