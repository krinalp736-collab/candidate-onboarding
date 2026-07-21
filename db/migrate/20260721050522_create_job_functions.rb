class CreateJobFunctions < ActiveRecord::Migration[8.1]
  def change
    create_table :job_functions do |t|
      t.string :name, null: false
      # Drives conditional logic in CandidateProfile: dentist/hygienist/specialist
      # show BIG registration + revenue fields; the rest hide them.
      t.string :clinical_group, null: false # dentist | assistant | front_office | practice_manager | technician
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :job_functions, :name, unique: true
  end
end
