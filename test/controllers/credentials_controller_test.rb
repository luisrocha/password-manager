require "test_helper"

class CredentialsControllerTest < ActionDispatch::IntegrationTest
  ENCRYPTED_PAYLOAD = "-----BEGIN PGP MESSAGE-----\nopaque-test-payload\n-----END PGP MESSAGE-----".freeze

  setup do
    @previous_vault_session_ttl = ENV["PASSWORD_MANAGER_VAULT_SESSION_TTL_MINUTES"]
    unlock!
  end

  teardown do
    if @previous_vault_session_ttl.nil?
      ENV.delete("PASSWORD_MANAGER_VAULT_SESSION_TTL_MINUTES")
    else
      ENV["PASSWORD_MANAGER_VAULT_SESSION_TTL_MINUTES"] = @previous_vault_session_ttl
    end
  end

  test "index renders successfully" do
    get credentials_url
    assert_response :success
    assert_includes response.body, 'data-controller="lock"'
    assert_includes response.body, 'data-action="submit-&gt;lock#clear"'
  end

  test "new renders successfully" do
    get new_credential_url
    assert_response :success
    assert_includes response.body, "data-controller=\"credential-form\""
    assert_not_includes response.body, "data-credential-form-encrypted-payload-value"
    assert_select "input[name='credential[name]'][required]", false
    assert_select "input[name='credential[domain]'][required]", false
    assert_select "input#credential_username_plaintext[required]", false
    assert_select "input#credential_password_plaintext[required]"
    assert_includes response.body, "data-controller=\"password-generator\""
    assert_includes response.body, "data-action=\"password-generator#generate\""
  end

  test "import renders successfully" do
    get import_credentials_url
    assert_response :success
    assert_includes response.body, "data-controller=\"credential-import\""
    assert_includes response.body, "data-action=\"submit-&gt;credential-import#submit\""
  end

  test "creates a credential" do
    assert_difference("Credential.count", 1) do
      post credentials_url, params: {
        credential: {
          name: "Example",
          domain: "example.com",
          category: "login",
          username: "alice",
          password: "secret",
          notes: "private notes",
          encrypted_secret_payload: ENCRYPTED_PAYLOAD
        }
      }
    end

    assert_redirected_to credentials_url
    credential = Credential.last
    assert_equal ENCRYPTED_PAYLOAD, credential.encrypted_secret_payload
    assert_not credential.attributes.key?("username")
    assert_not credential.attributes.key?("password")
    assert_not credential.attributes.key?("notes")
  end

  test "creates a credential with only name metadata" do
    assert_difference("Credential.count", 1) do
      post credentials_url, params: {
        credential: {
          name: "Example",
          domain: "",
          category: "login",
          encrypted_secret_payload: ENCRYPTED_PAYLOAD
        }
      }
    end

    assert_redirected_to credentials_url
  end

  test "creates a credential with only domain metadata" do
    assert_difference("Credential.count", 1) do
      post credentials_url, params: {
        credential: {
          name: "",
          domain: "example.com",
          category: "login",
          encrypted_secret_payload: ENCRYPTED_PAYLOAD
        }
      }
    end

    assert_redirected_to credentials_url
  end

  test "creates a credential with encrypted username only" do
    assert_difference("Credential.count", 1) do
      post credentials_url, params: {
        credential: {
          name: "",
          domain: "",
          category: "login",
          encrypted_secret_payload: ENCRYPTED_PAYLOAD
        }
      }
    end

    assert_redirected_to credentials_url
  end

  test "invalid create renders new page" do
    post credentials_url, params: {
      credential: {
        name: "",
        category: "login"
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "Add Credential"
    assert_includes response.body, "data-controller=\"credential-form\""
    assert_includes response.body, "data-controller=\"password-generator\""
    assert_includes response.body, "data-action=\"password-generator#generate\""
  end

  test "csv import post fails closed until browser encryption is implemented" do
    file = fixture_file_upload("1password.csv", "text/csv")

    assert_no_difference("Credential.count") do
      post import_credentials_url, params: { file: file }
    end

    assert_redirected_to import_credentials_url
  end

  test "encrypted csv import creates credentials" do
    assert_difference("Credential.count", 2) do
      post import_credentials_url, params: {
        encrypted_import: "1",
        credentials: {
          "0" => {
            name: "GitHub",
            domain: "github.com",
            category: "login",
            encrypted_secret_payload: ENCRYPTED_PAYLOAD
          },
          "1" => {
            name: "Server SSH",
            domain: "example.internal",
            category: "server",
            encrypted_secret_payload: ENCRYPTED_PAYLOAD
          }
        }
      }
    end

    assert_redirected_to credentials_url
    assert_equal ["GitHub", "Server SSH"], Credential.order(:name).pluck(:name)
    assert_equal [ENCRYPTED_PAYLOAD], Credential.distinct.pluck(:encrypted_secret_payload)
  end

  test "encrypted csv import rejects invalid rows without partial import" do
    assert_no_difference("Credential.count") do
      post import_credentials_url, params: {
        encrypted_import: "1",
        credentials: {
          "0" => {
            name: "",
            domain: "",
            category: "login",
            encrypted_secret_payload: ""
          },
          "1" => {
            name: "Server SSH",
            domain: "example.internal",
            category: "server",
            encrypted_secret_payload: ENCRYPTED_PAYLOAD
          }
        }
      }
    end

    assert_redirected_to import_credentials_url
  end

  test "encrypted csv import allows rows without name or domain" do
    assert_difference("Credential.count", 1) do
      post import_credentials_url, params: {
        encrypted_import: "1",
        credentials: {
          "0" => {
            name: "",
            domain: "",
            category: "login",
            encrypted_secret_payload: ENCRYPTED_PAYLOAD
          }
        }
      }
    end

    assert_redirected_to credentials_url
    credential = Credential.last
    assert_equal "", credential.name
    assert_equal "", credential.domain
  end

  test "encrypted csv import allows rows with blank imported password" do
    assert_difference("Credential.count", 1) do
      post import_credentials_url, params: {
        encrypted_import: "1",
        credentials: {
          "0" => {
            name: "Internal Jenkins",
            domain: "http://10.112.27.133:8080/hudson/login",
            category: "login",
            encrypted_secret_payload: ENCRYPTED_PAYLOAD
          }
        }
      }
    end

    assert_redirected_to credentials_url
  end

  test "missing import file redirects to import page" do
    post import_credentials_url

    assert_redirected_to import_credentials_url
  end

  test "search filters results" do
    Credential.create!(name: "GitHub", domain: "github.com", category: "login", encrypted_secret_payload: ENCRYPTED_PAYLOAD)
    Credential.create!(name: "Mail", domain: "mail.example.com", category: "login", encrypted_secret_payload: ENCRYPTED_PAYLOAD)

    get credentials_url, params: { q: "git" }

    assert_response :success
    assert_includes response.body, "GitHub"
    assert_not_includes response.body, "mail.example.com"
  end

  test "edit renders successfully" do
    credential = Credential.create!(
      name: "GitHub",
      domain: "github.com",
      category: "login",
      encrypted_secret_payload: ENCRYPTED_PAYLOAD
    )

    get edit_credential_url(credential)

    assert_response :success
    assert_includes response.body, "data-controller=\"credential-form\""
    assert_includes response.body, "data-credential-form-encrypted-payload-value="
    assert_includes response.body, ERB::Util.html_escape(ENCRYPTED_PAYLOAD)
    assert_not_includes response.body, "existing-secret"
    assert_includes response.body, "data-controller=\"password-generator\""
    assert_includes response.body, "data-password-generator-target=\"visibilityButton\""
    assert_includes response.body, "data-action=\"password-generator#toggleVisibility\""
    assert_includes response.body, "data-action=\"password-generator#generate\""
    assert_includes response.body, "aria-label=\"Show password\""
    assert_includes response.body, "aria-label=\"Generate password\""
    assert_includes response.body, "Include numbers"
    assert_includes response.body, "Include symbols"
  end

  test "index renders reveal controls without plaintext secret fields" do
    Credential.create!(
      name: "GitHub",
      domain: "github.com",
      category: "login",
      encrypted_secret_payload: ENCRYPTED_PAYLOAD
    )

    get credentials_url

    assert_response :success
    assert_includes response.body, "data-controller=\"credential-reveal\""
    assert_includes response.body, "signed-stream-name"
    assert_includes response.body, "id=\"credentials_index\""
    assert_includes response.body, "data-credential-reveal-encrypted-payload-value="
    assert_includes response.body, "data-credential-reveal-target=\"username\""
    assert_includes response.body, "data-action=\"credential-reveal#revealPassword\""
    assert_includes response.body, "data-action=\"credential-reveal#revealNotes\""
    assert_not_includes response.body, "alice@example.com"
    assert_not_includes response.body, "top-secret-password"
    assert_includes response.body, "Decrypting..."
    assert_includes response.body, "Hidden"
  end

  test "index does not subscribe search results to credential broadcasts" do
    Credential.create!(
      name: "GitHub",
      domain: "github.com",
      category: "login",
      encrypted_secret_payload: ENCRYPTED_PAYLOAD
    )

    get credentials_url, params: { q: "git" }

    assert_response :success
    assert_includes response.body, "id=\"credentials_index\""
    assert_not_includes response.body, "signed-stream-name"
  end

  test "updates a credential" do
    credential = Credential.create!(name: "GitHub", domain: "github.com", category: "login", encrypted_secret_payload: ENCRYPTED_PAYLOAD)
    updated_payload = "-----BEGIN PGP MESSAGE-----\nupdated-test-payload\n-----END PGP MESSAGE-----"

    patch credential_url(credential), params: {
      credential: {
        name: "GitHub Personal",
        domain: "github.com",
        category: "login",
        encrypted_secret_payload: updated_payload
      }
    }

    assert_redirected_to credentials_url
    assert_equal "GitHub Personal", credential.reload.name
    assert_equal updated_payload, credential.encrypted_secret_payload
  end

  test "update ignores plaintext secret params" do
    credential = Credential.create!(name: "GitHub", domain: "github.com", category: "login", encrypted_secret_payload: ENCRYPTED_PAYLOAD)
    updated_payload = "-----BEGIN PGP MESSAGE-----\nupdated-test-payload\n-----END PGP MESSAGE-----"

    patch credential_url(credential), params: {
      credential: {
        name: "GitHub",
        domain: "github.com",
        category: "login",
        username: "alice",
        password: "secret",
        notes: "private notes",
        encrypted_secret_payload: updated_payload
      }
    }

    assert_redirected_to credentials_url
    credential.reload
    assert_equal updated_payload, credential.encrypted_secret_payload
    assert_not credential.attributes.key?("username")
    assert_not credential.attributes.key?("password")
    assert_not credential.attributes.key?("notes")
  end

  test "deletes a credential" do
    credential = Credential.create!(name: "GitHub", domain: "github.com", category: "login", encrypted_secret_payload: ENCRYPTED_PAYLOAD)

    assert_difference("Credential.count", -1) do
      delete credential_url(credential)
    end

    assert_redirected_to credentials_url
  end

  test "redirects to unlock when session is locked" do
    delete lock_url
    get credentials_url

    assert_redirected_to unlock_url
  end

  test "redirects to unlock when vault session expires" do
    travel 31.minutes

    get credentials_url

    assert_redirected_to unlock_url
  end

  test "uses default vault session ttl when configured ttl is invalid" do
    ENV["PASSWORD_MANAGER_VAULT_SESSION_TTL_MINUTES"] = "0"

    travel 31.minutes

    get credentials_url

    assert_redirected_to unlock_url
  end
end
