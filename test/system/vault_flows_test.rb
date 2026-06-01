require "application_system_test_case"

class VaultFlowsTest < ApplicationSystemTestCase
  MASTER_PASSWORD = "correct horse battery staple"

  test "main vault flows" do
    backup_path = create_new_vault_key

    added = add_credential
    import_csv
    search_credentials(added[:name])
    edit_credential(added)
    delete_credential(added[:edited_name])

    lock_vault
    unlock_existing_key

    lock_vault
    import_existing_key(backup_path)
  ensure
    FileUtils.rm_f(backup_path) if backup_path
  end

  private

  def create_new_vault_key
    visit unlock_path

    assert_text "Password Manager"
    assert_text "Create a local vault key for this browser."

    fill_in "New master password", with: MASTER_PASSWORD
    fill_in "Confirm master password", with: MASTER_PASSWORD
    click_button "Create Vault Key"

    assert_text "Vault key created."
    assert_selector "a[download='password-manager-vault-backup.json']", text: "Download Backup"
    assert_match(/\Ablob:/, find("a", text: "Download Backup")["href"])

    backup_json = page.evaluate_script("window.localStorage.getItem('passwordManager.encryptedPrivateKey')")
    assert backup_json.present?, "Expected vault backup data in browser storage"

    backup_path = Rails.root.join("tmp", "system-vault-backup-#{SecureRandom.hex(8)}.json")
    File.write(backup_path, backup_json)

    click_button "Continue to Vault"
    assert_text "Vault unlocked."
    assert_credentials_index
    assert_backup_matches_registered_key(backup_json)

    backup_path
  end

  def add_credential
    credential = build(:credential)
    username = FFaker::Internet.user_name
    password = FFaker::Internet.password
    notes = "Created from a system test"

    click_link "Add Item"
    assert_text "Add Credential"

    fill_in "Name", with: credential.name
    fill_in "Domain", with: credential.domain
    fill_in "Username", with: username
    fill_in "Password", with: password
    fill_in "Notes", with: notes
    click_button "Save"

    assert_credentials_index
    assert_text "Credential saved."
    assert_text credential.name
    assert_text credential.domain
    assert_text username

    {
      name: credential.name,
      domain: credential.domain,
      username:,
      password:,
      notes:,
      edited_name: "Updated #{credential.name}",
      edited_domain: "updated-#{credential.domain}",
      edited_username: "updated-#{username}",
      edited_password: "updated-#{password}",
      edited_notes: "Updated from a system test"
    }
  end

  def import_csv
    click_link "Import CSV"
    assert_text "Import 1Password CSV"

    attach_file "file", Rails.root.join("test/fixtures/files/1password.csv")
    click_button "Import"

    assert_credentials_index
    assert_text "Imported 2 credentials."
    assert_text "GitHub"
    assert_text "github.com"
    assert_text "luis"
    assert_text "Server SSH"
  end

  def search_credentials(name)
    fill_in "Search by name or domain", with: name
    click_button "Search"

    assert_credentials_index(q: name)
    assert_text name
    assert_no_text "Server SSH"

    click_link "Clear search"
    assert_credentials_index
    assert_text "Server SSH"
  end

  def edit_credential(credential)
    within_desktop_row(credential[:name]) do
      find("[aria-label='Edit credential']").click
    end

    assert_text "Edit Credential"
    assert_field "Username", with: credential[:username]
    assert_field "Password", with: credential[:password]
    assert_field "Notes", with: credential[:notes]

    fill_in "Name", with: credential[:edited_name]
    fill_in "Domain", with: credential[:edited_domain]
    fill_in "Username", with: credential[:edited_username]
    fill_in "Password", with: credential[:edited_password]
    fill_in "Notes", with: credential[:edited_notes]
    click_button "Update"

    assert_credentials_index
    assert_text "Credential updated."
    assert_text credential[:edited_name]
    assert_text credential[:edited_domain]
    assert_text credential[:edited_username]
  end

  def delete_credential(name)
    within_desktop_row(name) do
      accept_confirm "Delete this credential?" do
        find("[aria-label='Delete credential']").click
      end
    end

    assert_credentials_index
    assert_text "Credential deleted."
    assert_no_text name
  end

  def lock_vault
    click_button "Lock Vault"

    assert_text "Vault locked."
    assert_text "Enter your master password to unlock the vault."
  end

  def unlock_existing_key
    fill_in "Master password", with: MASTER_PASSWORD
    click_button "Unlock"

    assert_text "Vault unlocked."
    assert_credentials_index
  end

  def import_existing_key(backup_path)
    page.execute_script("window.localStorage.removeItem('passwordManager.encryptedPrivateKey')")
    visit unlock_path

    assert_text "Vault key not found on this browser. Import your vault key backup to continue."
    attach_file "vault_backup_file", backup_path
    assert_attached_backup_can_be_verified
    click_button "Import Backup"

    assert_text "Backup imported. Enter your master password to unlock."
    fill_in "Master password", with: MASTER_PASSWORD
    click_button "Unlock"

    assert_text "Vault unlocked."
    assert_credentials_index
  end

  def assert_attached_backup_can_be_verified
    result = page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      const file = document.querySelector("#vault_backup_file").files[0]

      if (!file) {
        done("missing-file")
        return
      }

      file.text().then((text) => {
        const backup = JSON.parse(text)
        if (!backup.signing || !backup.signing.publicKeySpki) {
          done("missing-key")
          return
        }
        return fetch("/unlock/verify_backup_key", {
          method: "POST",
          headers: Object.assign(
            { "Content-Type": "application/json" },
            document.querySelector("meta[name='csrf-token']")?.content
              ? { "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content }
              : {}
          ),
          body: JSON.stringify({
            signing_public_key_spki: backup.signing && backup.signing.publicKeySpki
          })
        }).then((response) => response.status)
      }).then((response) => {
        if (response) done(response)
      }).catch((error) => {
        done(error.name)
      })
    JS

    assert_equal 200, result, "Expected the attached backup file to pass server key verification"
  end

  def assert_backup_matches_registered_key(backup_json)
    backup_key = JSON.parse(backup_json).dig("signing", "publicKeySpki")
    registered_key = VaultSigningKey.current&.public_key_spki

    assert backup_key.present?, "Expected backup to include a signing public key"
    assert registered_key.present?, "Expected continuing to the vault to register a signing public key"
    assert backup_key == registered_key, "Expected the backup signing key to match the registered signing key"
  end

  def within_desktop_row(text, &block)
    within("table tbody tr", text:, &block)
  end

  def assert_credentials_index(q: nil)
    expected_path = q.present? ? credentials_path(q:) : credentials_path

    assert_current_path expected_path
    assert_selector "h2", text: /\AStored Items \(\d+\)\z/
  end
end
