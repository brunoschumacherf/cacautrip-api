class CreateConversations < ActiveRecord::Migration[7.1]
  def change
    create_table :conversations do |t|
      t.references :tourist, null: false, foreign_key: { to_table: :users }
      t.references :guide, null: true, foreign_key: { to_table: :users }
      t.references :driver, null: true, foreign_key: { to_table: :users }
      t.string :status, default: 'active'

      t.timestamps
    end
  end
end