require "test_helper"

class CredentialTest < ActiveSupport::TestCase
  test "validates required attributes" do
    credential = Credential.new

    assert_not credential.valid?
    assert_includes credential.errors[:name], "can't be blank"
  end

  test "searches by name and domain" do
    github = Credential.create!(name: "GitHub", domain: "github.com", category: "login")
    _gitlab = Credential.create!(name: "GitLab", domain: "gitlab.com", category: "login")

    by_name = Credential.search("Hub")
    by_domain = Credential.search("lab.com")

    assert_includes by_name, github
    assert_equal 1, by_domain.count
  end

  test "encrypts sensitive fields" do
    credential = Credential.create!(
      name: "Bank",
      domain: "bank.example",
      category: "login",
      username: "alice",
      password: "top-secret"
    )

    db_row = Credential.connection.select_one("SELECT username, password FROM credentials WHERE id = #{credential.id}")

    assert_not_equal "alice", db_row["username"]
    assert_not_equal "top-secret", db_row["password"]
    assert_equal "alice", credential.reload.username
    assert_equal "top-secret", credential.password
  end
end
