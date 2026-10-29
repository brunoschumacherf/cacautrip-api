class CreateGuideProfiles < ActiveRecord::Migration[7.1]
  def change
    create_table :guide_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.text :specialization
      t.text :languages
      t.boolean :verified_documents, default: false
      t.string :subscription_plan

      t.timestamps
    end
  end
end
