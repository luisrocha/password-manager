require "test_helper"

class CredentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    unlock!
  end

  test "index renders successfully" do
    get credentials_url
    assert_response :success
  end

  test "creates a credential" do
    assert_difference("Credential.count", 1) do
      post credentials_url, params: {
        credential: {
          name: "Example",
          domain: "example.com",
          category: "login",
          username: "alice",
          password: "secret"
        }
      }
    end

    assert_redirected_to credentials_url
  end

  test "imports a csv file" do
    file = fixture_file_upload("1password.csv", "text/csv")

    assert_difference("Credential.count", 2) do
      post import_credentials_url, params: { file: file }
    end

    assert_redirected_to credentials_url
  end

  test "search filters results" do
    Credential.create!(name: "GitHub", domain: "github.com", category: "login")
    Credential.create!(name: "Mail", domain: "mail.example.com", category: "login")

    get credentials_url, params: { q: "git" }

    assert_response :success
    assert_includes response.body, "GitHub"
    assert_not_includes response.body, "mail.example.com"
  end

  test "edit renders successfully" do
    credential = Credential.create!(name: "GitHub", domain: "github.com", category: "login")

    get edit_credential_url(credential)

    assert_response :success
  end

  test "updates a credential" do
    credential = Credential.create!(name: "GitHub", domain: "github.com", category: "login")

    patch credential_url(credential), params: {
      credential: {
        name: "GitHub Personal",
        domain: "github.com",
        category: "login"
      }
    }

    assert_redirected_to credentials_url
    assert_equal "GitHub Personal", credential.reload.name
  end

  test "deletes a credential" do
    credential = Credential.create!(name: "GitHub", domain: "github.com", category: "login")

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
end
