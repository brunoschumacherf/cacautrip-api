class AddDetailsToBookings < ActiveRecord::Migration[7.1]
  def change
    add_column :bookings, :date, :string
    add_column :bookings, :meeting_point, :string
  end
end
