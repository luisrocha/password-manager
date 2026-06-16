require "test_helper"

class MobileDeviceTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  test "issues a device with a one-time raw token" do
    assert_broadcasts MobileDevice.broadcast_stream_name, 1 do
      @device, @token = MobileDevice.issue!(name: "Luis phone")
    end

    device = @device
    token = @token

    assert_equal "Luis phone", device.name
    assert token.present?
    assert_not_equal token, device.token_digest
    assert_equal MobileDevice.digest(token), device.token_digest
  end

  test "broadcasts device list changes" do
    device, token = MobileDevice.issue!(name: "Luis phone")

    assert_broadcasts MobileDevice.broadcast_stream_name, 1 do
      device.revoke!
    end

    assert_broadcasts MobileDevice.broadcast_stream_name, 1 do
      device.destroy!
    end
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
