class CreateMobileDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :mobile_devices do |t|
      t.string :name, null: false
      t.string :token_digest, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :mobile_devices, :token_digest, unique: true
    add_index :mobile_devices, :revoked_at
  end
end
