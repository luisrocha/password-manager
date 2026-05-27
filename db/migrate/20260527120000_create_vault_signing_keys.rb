class CreateVaultSigningKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :vault_signing_keys do |t|
      t.text :public_key_spki, null: false

      t.timestamps
    end
  end
end
