class CreateCandidateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :candidate_documents do |t|
      t.references :candidate_profile, null: false, foreign_key: true
      t.integer :document_type, null: false, default: 0 # enum: cv
      t.string :original_filename
      t.string :content_type
      t.bigint :file_size
      t.integer :parsing_status, null: false, default: 0 # enum: pending | processing | completed | failed
      t.text :parsing_error
      t.datetime :parsed_at

      t.timestamps
    end
  end
end
