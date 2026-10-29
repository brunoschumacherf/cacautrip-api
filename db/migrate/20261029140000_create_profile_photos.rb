class CreateProfilePhotos < ActiveRecord::Migration[7.1]
  def change
    create_table :profile_photos do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.binary :image_data, null: false
      t.string :content_type, null: false
      t.string :version, null: false
      t.timestamps
    end
  end
end
