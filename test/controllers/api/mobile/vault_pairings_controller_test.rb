require "test_helper"

class Api::Mobile::VaultPairingsControllerTest < ActionDispatch::IntegrationTest
  test "redeems a mobile vault pairing once" do
    pairing = MobileVaultPairing.create!(compact_mobile_vault_payload)

    post api_mobile_vault_pairings_redeem_url, params: { code: pairing.fetch(:code) }

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal compact_mobile_vault_payload, response_body.fetch("encryptedVaultBackup")
    assert_equal "Mobile app", response_body.dig("device", "name")
    assert response_body.fetch("deviceToken").present?
    assert_equal 1, MobileDevice.count
    assert_equal MobileDevice.digest(response_body.fetch("deviceToken")), MobileDevice.last.token_digest
    assert_not_equal response_body.fetch("deviceToken"), MobileDevice.last.token_digest

    post api_mobile_vault_pairings_redeem_url, params: { code: pairing.fetch(:code) }

    assert_response :not_found
    assert_equal "pairing_not_found", JSON.parse(response.body).fetch("code")
  end

  test "returns not found for unknown mobile vault pairing code" do
    assert_no_difference("MobileDevice.count") do
      post api_mobile_vault_pairings_redeem_url, params: { code: "NOPE-0000" }
    end

    assert_response :not_found
    assert_equal "pairing_not_found", JSON.parse(response.body).fetch("code")
  end

  test "normalizes pairing codes before redeeming" do
    pairing = MobileVaultPairing.create!(compact_mobile_vault_payload)

    post api_mobile_vault_pairings_redeem_url,
      params: { code: pairing.fetch(:code).delete("-").downcase }

    assert_response :success
    assert_equal compact_mobile_vault_payload, response.parsed_body.fetch("encryptedVaultBackup")
  end

  test "redeems a mobile vault pairing with a device name" do
    pairing = MobileVaultPairing.create!(compact_mobile_vault_payload)

    post api_mobile_vault_pairings_redeem_url,
      params: { code: pairing.fetch(:code), deviceName: "Luis Pixel" }

    assert_response :success
    assert_equal "Luis Pixel", response.parsed_body.dig("device", "name")
    assert_equal "Luis Pixel", MobileDevice.last.name
  end

  private

  def compact_mobile_vault_payload
    JSON.generate({
      t: "pmv",
      v: 1,
      d: {
        p: "public-key",
        e: "encrypted-private-key",
        s: { p: "signing-public-key", e: "encrypted-signing-key", i: "signing-iv" },
        k: { v: 19, t: 2, m: 19_456, p: 1, h: 32, s: "salt" },
        c: { i: "private-key-iv" }
      }
    })
  end
end
