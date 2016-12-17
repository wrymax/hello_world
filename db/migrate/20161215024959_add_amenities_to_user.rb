class AddAmenitiesToUser < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :amenities, :string
  end
end
