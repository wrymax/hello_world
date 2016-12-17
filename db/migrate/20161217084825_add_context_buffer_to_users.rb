class AddContextBufferToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :context_buffer, :text
  end
end
