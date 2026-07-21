class CreateCandidateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :candidate_profiles do |t|
      t.references :user, null: true, foreign_key: true
      t.references :job_function, null: true, foreign_key: true

      # Wizard state
      t.string :onboarding_step, null: false, default: "cv_upload"
      t.datetime :completed_at
      t.datetime :consent_given_at

      # 3.1 Personal details
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :phone_number
      t.string :city
      t.string :country

      # 3.2 Job preferences (job_function_id above)
      # MySQL 5.7's JSON type doesn't support column defaults (added in 8.0.13)
      # — default: [] is set at the Ruby attribute level instead (see
      # CandidateProfile).
      t.json :preferred_regions, null: false
      t.integer :max_travel_time
      t.json :transport_types, null: false # bike | scooter | public_transport | car
      t.integer :search_status # enum: active | passive | inactive
      t.text :reason_for_looking

      # 3.3 Employment and compensation
      t.json :employment_types, null: false # employed | self_employed | freelance | percentage_based
      t.integer :desired_gross_salary
      t.integer :desired_percentage
      t.integer :average_daily_revenue
      t.integer :big_registration_status # enum: big_registered | in_progress | under_supervision | not_applicable
      t.string :big_number
      t.integer :years_of_experience

      # 3.7 Availability
      t.json :available_working_days, null: false # monday..sunday
      t.date :available_from
      t.string :notice_period

      # 3.8 Additional information
      t.text :motivation
      t.text :internal_notes
      t.text :professional_summary

      t.timestamps
    end

    add_index :candidate_profiles, :email
  end
end
