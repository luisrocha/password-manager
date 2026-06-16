require "test_helper"

class MobileDeviceTest < ActiveSupport::TestCase
  test "issues a device with a one-time raw token" do
    device, token = MobileDevice.issue!(name: "Luis phone")

    assert_equal "Luis phone", device.name
    assert token.present?
    assert_not_equal token, device.token_digest
    assert_equal MobileDevice.digest(token), device.token_digest
  end

  test "authenticates active device tokens and updates last used time" do
    device, token = MobileDevice.issue!

    assert_equal device, MobileDevice.authenticate(token)
    assert device.reload.last_used_at.present?
  end

  test "does not authenticate revoked device tokens" do
    device, token = MobileDevice.issue!
    device.revoke!

    assert_nil MobileDevice.authenticate(token)
  end
end
