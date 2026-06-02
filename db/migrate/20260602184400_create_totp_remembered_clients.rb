class CreateTotpRememberedClients < ActiveRecord::Migration[8.1]
  def change
    create_table :totp_remembered_clients do |t|
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :totp_remembered_clients, :token_digest, unique: true
    add_index :totp_remembered_clients, :expires_at
  end
end
