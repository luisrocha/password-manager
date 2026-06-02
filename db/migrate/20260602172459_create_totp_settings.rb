class CreateTotpSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :totp_settings do |t|
      t.string :secret, null: false
      t.datetime :enabled_at

      t.timestamps
    end
  end
end
