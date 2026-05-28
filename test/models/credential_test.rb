require "test_helper"

class CredentialTest < ActiveSupport::TestCase
  ENCRYPTED_PAYLOAD = "-----BEGIN PGP MESSAGE-----\nopaque-test-payload\n-----END PGP MESSAGE-----".freeze

  test "validates required attributes" do
    credential = Credential.new

    assert_not credential.valid?
    assert_includes credential.errors[:name], "can't be blank"
    assert_includes credential.errors[:domain], "can't be blank"
    assert_includes credential.errors[:encrypted_secret_payload], "can't be blank"
  end

  test "searches by name and domain" do
    github = Credential.create!(name: "GitHub", domain: "github.com", category: "login", encrypted_secret_payload: ENCRYPTED_PAYLOAD)
    _gitlab = Credential.create!(name: "GitLab", domain: "gitlab.com", category: "login", encrypted_secret_payload: ENCRYPTED_PAYLOAD)

    by_name = Credential.search("Hub")
    by_domain = Credential.search("lab.com")

    assert_includes by_name, github
    assert_equal 1, by_domain.count
  end

  test "stores only encrypted secret payload" do
    credential = Credential.create!(
      name: "Bank",
      domain: "bank.example",
      category: "login",
      encrypted_secret_payload: ENCRYPTED_PAYLOAD
    )

    db_row = Credential.connection.select_one("SELECT * FROM credentials WHERE id = #{credential.id}")

    assert_equal ENCRYPTED_PAYLOAD, db_row["encrypted_secret_payload"]
    assert_not db_row.key?("username")
    assert_not db_row.key?("password")
    assert_not db_row.key?("notes")
  end

  test "allows long domain values without character-length restriction" do
    long_domain = ("a" * 260) + ".example/custom:path?param=1"
    credential = Credential.new(name: "Long Domain", domain: long_domain, category: "login", encrypted_secret_payload: ENCRYPTED_PAYLOAD)

    assert credential.valid?
  end
end
