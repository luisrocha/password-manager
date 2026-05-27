require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
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

  test "unlock page marks registered vault and hides create new key action" do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(MasterPasswordIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )

    get unlock_url

    assert_response :success
    assert_includes response.body, 'data-vault-registered="true"'
    assert_not_includes response.body, "Create new key"
  end

  test "create rejects unsigned unlock attempts" do
    get unlock_url
    post unlock_url

    assert_redirected_to unlock_url
    follow_redirect!
    assert_includes response.body, "Vault unlock proof is invalid."
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

  test "create rejects proof from an unregistered signing key" do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(MasterPasswordIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
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
    Credential.create!(name: "Existing", category: "login")

    get unlock_url

    assert_no_difference("VaultSigningKey.count") do
      post unlock_url, params: unlock_proof_params
    end
    assert_redirected_to unlock_url
  end
end
