class CreateRoutes < ActiveRecord::Migration[7.1]
  def change
    create_table :routes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.string :destination
      t.decimal :budget
      t.decimal :total_estimated_cost
      t.jsonb :preferences

      t.timestamps
    end
  end
end
