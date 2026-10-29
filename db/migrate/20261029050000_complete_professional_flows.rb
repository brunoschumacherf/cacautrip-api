class CompleteProfessionalFlows < ActiveRecord::Migration[7.1]
  def change
    add_column :guide_profiles, :description, :text
    add_column :guide_profiles, :image_url, :string
    add_column :bookings, :payment_polls, :integer, default: 0, null: false
  end
end
