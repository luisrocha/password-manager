require "test_helper"

class Api::Mobile::VaultPairingsControllerTest < ActionDispatch::IntegrationTest
  test "redeems a mobile vault pairing once" do
    pairing = MobileVaultPairing.create!(compact_mobile_vault_payload)

    post api_mobile_vault_pairings_redeem_url, params: { code: pairing.fetch(:code) }

    assert_response :success
    assert_equal compact_mobile_vault_payload, JSON.parse(response.body).fetch("encryptedVaultBackup")

    post api_mobile_vault_pairings_redeem_url, params: { code: pairing.fetch(:code) }

    assert_response :not_found
    assert_equal "pairing_not_found", JSON.parse(response.body).fetch("code")
  end

  test "returns not found for unknown mobile vault pairing code" do
    post api_mobile_vault_pairings_redeem_url, params: { code: "NOPE-0000" }

    assert_response :not_found
    assert_equal "pairing_not_found", JSON.parse(response.body).fetch("code")
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
