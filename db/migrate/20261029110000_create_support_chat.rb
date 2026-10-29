class CreateSupportChat < ActiveRecord::Migration[7.1]
  def up
    change_column_default :support_tickets, :status, from: 'open', to: 'ai'
    add_column :support_tickets, :human_requested_at, :datetime
    add_column :support_tickets, :ai_request_id, :string
    add_column :support_tickets, :ai_started_at, :datetime
    add_reference :support_tickets, :assigned_staff, foreign_key: { to_table: :admin_users, on_delete: :nullify }
    add_index :support_tickets, [:status, :updated_at]
    create_table :support_messages do |t|
      t.references :support_ticket, null: false, foreign_key: true
      t.references :admin_user, foreign_key: { on_delete: :nullify }
      t.string :role, null: false
      t.string :sender_name
      t.text :content, null: false
      t.timestamps
    end
    add_index :support_messages, [:support_ticket_id, :id]
    execute <<~SQL
      UPDATE support_tickets SET human_requested_at = created_at WHERE status <> 'ai';
      INSERT INTO support_messages (support_ticket_id, role, content, created_at, updated_at)
        SELECT id, 'user', message, created_at, created_at FROM support_tickets;
      INSERT INTO support_messages (support_ticket_id, role, sender_name, content, created_at, updated_at)
        SELECT id, 'staff', 'Equipe de suporte', reply, updated_at, updated_at
        FROM support_tickets WHERE reply IS NOT NULL AND TRIM(reply) <> '';
    SQL
  end

  def down
    drop_table :support_messages
    remove_index :support_tickets, [:status, :updated_at]
    remove_reference :support_tickets, :assigned_staff, foreign_key: { to_table: :admin_users }
    remove_column :support_tickets, :human_requested_at
    remove_column :support_tickets, :ai_request_id
    remove_column :support_tickets, :ai_started_at
    execute "UPDATE support_tickets SET status = 'open' WHERE status = 'ai'"
    change_column_default :support_tickets, :status, from: 'ai', to: 'open'
  end
end
