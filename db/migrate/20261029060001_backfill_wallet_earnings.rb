class BackfillWalletEarnings < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      UPDATE bookings
      SET fee_amount = ROUND(total_amount * 0.10, 2),
          professional_amount = total_amount - ROUND(total_amount * 0.10, 2)
      WHERE payment_status = 'approved' AND professional_amount = 0;

      INSERT INTO wallet_entries (user_id, booking_id, kind, amount, status, created_at, updated_at)
      SELECT providers.user_id, bookings.id, 'earning', bookings.professional_amount,
             CASE WHEN bookings.status = 'completed' THEN 'available' ELSE 'pending' END,
             CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM bookings
      JOIN (
        SELECT id, user_id, 'Guia' AS service_type FROM guide_profiles
        UNION ALL
        SELECT id, user_id, 'Motorista' AS service_type FROM driver_profiles
      ) providers ON providers.id = bookings.service_id AND providers.service_type = bookings.service_type
      WHERE bookings.payment_status = 'approved' AND bookings.status IN ('confirmed', 'completed')
      ON CONFLICT (booking_id, kind) DO NOTHING;
    SQL
  end

  def down
    # Os créditos representam pagamentos existentes; não apagar lançamentos financeiros.
    raise ActiveRecord::IrreversibleMigration
  end
end
