class CreateUsers < ActiveRecord::Migration[5.0]
  def change
    create_table :users do |t|
      t.string :fb_id
      t.string :session_id
      t.string :location
      t.datetime :datetime
      t.integer :nights_count
      t.float :budget_per_night

      t.timestamps
    end
  end
end
