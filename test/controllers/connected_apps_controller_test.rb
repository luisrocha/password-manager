require "test_helper"

class ConnectedAppsControllerTest < ActionDispatch::IntegrationTest
  test "index renders extension connection page when vault is unlocked" do
    unlock!

    get connected_apps_url

    assert_response :success
    assert_includes response.body, "Connected apps"
    assert_includes response.body, "Connect Extension"
    assert_includes response.body, 'data-action="extension-connect#connectExtension"'
  end

  test "index redirects to unlock when vault is locked" do
    get connected_apps_url

    assert_redirected_to unlock_url
  end
end
