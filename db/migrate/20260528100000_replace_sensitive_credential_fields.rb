# frozen_string_literal: true

class ReplaceSensitiveCredentialFields < ActiveRecord::Migration[8.1]
  def change
    remove_column :credentials, :username, :text
    remove_column :credentials, :password, :text
    remove_column :credentials, :notes, :text

    add_column :credentials, :encrypted_secret_payload, :text, null: false
  end
end
