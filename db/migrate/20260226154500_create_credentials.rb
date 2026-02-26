class CreateCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :credentials do |t|
      t.string :name, null: false
      t.string :domain
      t.string :category, null: false, default: "login"
      t.text :username
      t.text :password
      t.text :notes

      t.timestamps
    end

    add_index :credentials, :name
    add_index :credentials, :domain
  end
end
