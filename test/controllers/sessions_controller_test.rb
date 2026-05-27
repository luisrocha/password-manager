require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "unlock page renders client vault flow" do
    get unlock_url

    assert_response :success
    assert_includes response.body, 'data-controller="unlock"'
    assert_includes response.body, 'data-unlock-target="setupPanel"'
    assert_includes response.body, 'data-unlock-target="unlockPanel"'
    assert_includes response.body, 'data-unlock-target="importPanel"'
  end
end
