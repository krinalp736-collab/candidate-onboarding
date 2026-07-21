class CreateSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :skills do |t|
      t.string :name, null: false
      t.references :job_function, null: false, foreign_key: true

      t.timestamps
    end

    add_index :skills, [ :job_function_id, :name ], unique: true
  end
end
