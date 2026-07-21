class CreateEducations < ActiveRecord::Migration[8.1]
  def change
    create_table :educations do |t|
      t.references :candidate_profile, null: false, foreign_key: true
      t.string :institution
      t.string :study, null: false
      t.string :city_and_country
      t.integer :level # enum: mbo | hbo | bachelor | master | doctor | course
      t.date :start_date
      t.date :end_date

      # CV-parsing provenance: lets the review screen show "Extracted from CV /
      # Please check" vs a plain candidate-entered record.
      t.integer :source, null: false, default: 0 # enum: manual | extracted
      t.boolean :needs_review, null: false, default: false

      t.timestamps
    end
  end
end
