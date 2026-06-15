require "test_helper"

class ConnectedAppsControllerTest < ActionDispatch::IntegrationTest
  test "index renders extension connection page when vault is unlocked" do
    unlock!

    get connected_apps_url

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_includes response.body, "Connected apps"
    assert_includes response.body, '<meta name="turbo-cache-control" content="no-cache">'
    assert_includes response.body, "Connect Extension"
    assert_includes response.body, "Set up mobile app"
    assert_includes response.body, "Create pairing code"
    assert_includes response.body, 'data-action="extension-connect#connectExtension"'
    assert_includes response.body, 'data-action="mobile-app-setup#createPairingCode"'
  end

  test "index redirects to unlock when vault is locked" do
    get connected_apps_url

    assert_redirected_to unlock_url
  end

  test "index redirects to unlock after vault is locked" do
    unlock!

    delete lock_url
    get connected_apps_url

    assert_redirected_to unlock_url
  end

  test "creates a mobile pairing code when vault is unlocked" do
    unlock!

    post connected_apps_mobile_pairings_url,
      params: { encrypted_vault_backup: compact_mobile_vault_payload }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_match(/\A[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{4}-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{4}\z/, response_body.fetch("code"))
    assert_equal 300, response_body.fetch("expires_in_seconds")
    assert_equal compact_mobile_vault_payload, Rails.cache.read(MobileVaultPairing.cache_key(response_body.fetch("code")))
  end

  test "rejects invalid mobile pairing payloads" do
    unlock!

    post connected_apps_mobile_pairings_url,
      params: { encrypted_vault_backup: "{}" }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :unprocessable_entity
  end

  test "create mobile pairing redirects to unlock when vault is locked" do
    post connected_apps_mobile_pairings_url,
      params: { encrypted_vault_backup: compact_mobile_vault_payload }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_redirected_to unlock_url
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
