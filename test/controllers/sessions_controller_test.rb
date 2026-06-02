require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_setup_token = ENV["PASSWORD_MANAGER_SETUP_TOKEN"]
    ENV["PASSWORD_MANAGER_SETUP_TOKEN"] = "server-setup-token"
  end

  teardown do
    if @original_setup_token.nil?
      ENV.delete("PASSWORD_MANAGER_SETUP_TOKEN")
    else
      ENV["PASSWORD_MANAGER_SETUP_TOKEN"] = @original_setup_token
    end
  end

  test "unlock page renders client vault flow" do
    get unlock_url

    assert_response :success
    assert_includes response.body, 'data-controller="unlock"'
    assert_includes response.body, 'data-unlock-target="challenge"'
    assert_includes response.body, 'data-vault-registered="false"'
    assert_includes response.body, 'data-unlock-target="setupPanel"'
    assert_includes response.body, 'data-unlock-target="unlockPanel"'
    assert_includes response.body, 'data-unlock-target="importPanel"'
  end

  test "unlock page renders setup token field before vault registration" do
    get unlock_url

    assert_response :success
    assert_includes response.body, 'data-setup-token-required="true"'
    assert_includes response.body, 'placeholder="Setup token"'
    assert_equal 1, response.body.scan('placeholder="Setup token"').count
  end

  test "unlock page exposes missing setup token state before vault registration" do
    ENV.delete("PASSWORD_MANAGER_SETUP_TOKEN")

    get unlock_url

    assert_response :success
    assert_includes response.body, 'data-setup-token-configured="false"'
  end

  test "unlock page marks registered vault and hides create new key action" do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )

    get unlock_url

    assert_response :success
    assert_includes response.body, 'data-vault-registered="true"'
    assert_includes response.body, 'data-setup-token-required="false"'
    assert_includes response.body, 'data-setup-token-configured="true"'
    assert_not_includes response.body, "Create new key"
    assert_not_includes response.body, 'placeholder="Setup token"'
    assert_not_includes response.body, "Setup token is not configured."
  end

  test "create rejects unsigned unlock attempts" do
    get unlock_url
    post unlock_url

    assert_redirected_to unlock_url
    follow_redirect!
    assert_includes response.body, "Vault unlock proof is invalid."
  end

  test "create rejects password params without unlock proof" do
    get unlock_url

    assert_no_difference("VaultSigningKey.count") do
      post unlock_url, params: {
        master_password: "unused-password-param",
        local_master_password: "unused-password-param"
      }
    end

    assert_redirected_to unlock_url
    get credentials_url
    assert_redirected_to unlock_url
  end

  test "create establishes web session gate with valid signed challenge" do
    get unlock_url

    assert_difference("VaultSigningKey.count", 1) do
      post unlock_url, params: unlock_proof_params
    end

    assert_redirected_to credentials_url
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Vault unlocked."
  end

  test "create rejects first key registration without configured setup token" do
    get unlock_url

    assert_no_difference("VaultSigningKey.count") do
      post unlock_url, params: unlock_proof_params.except(:setup_token)
    end

    assert_redirected_to unlock_url
  end

  test "create accepts first key registration with configured setup token" do
    get unlock_url

    assert_difference("VaultSigningKey.count", 1) do
      post unlock_url, params: unlock_proof_params.merge(setup_token: "server-setup-token")
    end

    assert_redirected_to credentials_url
  end

  test "create unlocks registered vault without setup token" do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )

    get unlock_url

    post unlock_url, params: unlock_proof_params.except(:setup_token)

    assert_redirected_to credentials_url
  end

  test "create redirects to totp challenge when two-factor unlock is enabled" do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    TotpSetting.create!(secret: TotpSetting.generate_secret, enabled_at: Time.current)

    get unlock_url
    post unlock_url, params: unlock_proof_params.except(:setup_token)

    assert_redirected_to totp_challenge_url
  end

  test "create rejects first key registration when setup token is missing from the environment" do
    ENV.delete("PASSWORD_MANAGER_SETUP_TOKEN")

    get unlock_url

    assert_no_difference("VaultSigningKey.count") do
      post unlock_url, params: unlock_proof_params.merge(setup_token: "anything")
    end

    assert_redirected_to unlock_url
  end

  test "create rejects reused unlock challenge" do
    get unlock_url
    proof_params = unlock_proof_params

    post unlock_url, params: proof_params
    assert_redirected_to credentials_url

    post unlock_url, params: proof_params
    assert_redirected_to unlock_url
  end

  test "create rejects proof from an unregistered signing key" do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    attacker_key = OpenSSL::PKey::EC.generate("prime256v1")

    get unlock_url
    challenge = response.body.match(/data-challenge="([^"]+)"/)[1]
    post unlock_url, params: {
      unlock_signature: Base64.strict_encode64(attacker_key.sign(OpenSSL::Digest::SHA256.new, challenge)),
      signing_public_key_spki: Base64.strict_encode64(attacker_key.public_to_der)
    }

    assert_redirected_to unlock_url
  end

  test "create rejects first key registration when credentials already exist" do
    Credential.create!(
      name: "Existing",
      domain: "existing.example",
      category: "login",
      encrypted_secret_payload: "-----BEGIN PGP MESSAGE-----\nopaque-test-payload\n-----END PGP MESSAGE-----"
    )

    get unlock_url

    assert_no_difference("VaultSigningKey.count") do
      post unlock_url, params: unlock_proof_params
    end
    assert_redirected_to unlock_url
  end

  test "verify backup key accepts when no vault signing key exists yet" do
    post "/unlock/verify_backup_key", params: {
      signing_public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    }, as: :json

    assert_response :success
    assert_equal true, response.parsed_body["ok"]
  end

  test "verify backup key accepts matching registered signing key" do
    public_key_spki = Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    VaultSigningKey.create!(public_key_spki:)

    post "/unlock/verify_backup_key", params: { signing_public_key_spki: public_key_spki }, as: :json

    assert_response :success
    assert_equal true, response.parsed_body["ok"]
  end

  test "verify backup key rejects mismatched registered signing key" do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    other_key = OpenSSL::PKey::EC.generate("prime256v1")

    post "/unlock/verify_backup_key", params: {
      signing_public_key_spki: Base64.strict_encode64(other_key.public_to_der)
    }, as: :json

    assert_response :unprocessable_entity
    assert_equal false, response.parsed_body["ok"]
    assert_equal "backup_key_mismatch", response.parsed_body["code"]
  end

  test "verify setup token accepts configured token before vault registration" do
    post "/unlock/verify_setup_token", params: { setup_token: "server-setup-token" }, as: :json

    assert_response :success
    assert_equal true, response.parsed_body["ok"]
  end

  test "verify setup token rejects wrong token before vault registration" do
    post "/unlock/verify_setup_token", params: { setup_token: "wrong-token" }, as: :json

    assert_response :unauthorized
    assert_equal false, response.parsed_body["ok"]
    assert_equal "invalid_setup_token", response.parsed_body["code"]
  end

  test "verify setup token rejects missing configured token before vault registration" do
    ENV.delete("PASSWORD_MANAGER_SETUP_TOKEN")

    post "/unlock/verify_setup_token", params: { setup_token: "server-setup-token" }, as: :json

    assert_response :unauthorized
    assert_equal false, response.parsed_body["ok"]
    assert_equal "invalid_setup_token", response.parsed_body["code"]
  end

  test "verify setup token rejects after vault registration" do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )

    post "/unlock/verify_setup_token", params: { setup_token: "server-setup-token" }, as: :json

    assert_response :unprocessable_entity
    assert_equal false, response.parsed_body["ok"]
    assert_equal "vault_already_registered", response.parsed_body["code"]
  end
end
