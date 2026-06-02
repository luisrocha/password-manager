class AddRecoveryCodesToTotpSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :totp_settings, :recovery_code_digests, :text, null: false, default: "[]"
  end
end
