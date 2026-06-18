class NormalizeCredentialClientUidIdempotency < ActiveRecord::Migration[8.1]
  def change
    add_column :credentials, :client_uid, :string unless column_exists?(:credentials, :client_uid)

    unless index_exists?(:credentials, :client_uid, unique: true)
      add_index :credentials, :client_uid, unique: true, where: "client_uid IS NOT NULL"
    end
  end
end
