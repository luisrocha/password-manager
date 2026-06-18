class AddMobileCreateIdempotencyToCredentials < ActiveRecord::Migration[8.1]
  def change
    add_column :credentials, :client_uid, :string
    add_index :credentials, :client_uid, unique: true, where: "client_uid IS NOT NULL"
  end
end
