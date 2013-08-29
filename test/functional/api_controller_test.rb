require 'test_helper'

class ApiControllerTest < ActionController::TestCase
  test "should get login" do
    get :login
    assert_response :success
  end

  test "should get advertise" do
    get :advertise
    assert_response :success
  end

end
