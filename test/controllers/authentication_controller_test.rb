require 'test_helper'

class AuthenticationControllerTest < ActionDispatch::IntegrationTest
  test 'signup returns a session without gov verification' do
    post '/signup', params: { name: 'Nova conta', email: 'signup-test@example.com', password: 'secret123' }, as: :json
    assert_response :created
    assert response.parsed_body['token'].present?
    assert_equal false, response.parsed_body.dig('user', 'gov_verified')
  end

  test 'login returns session accepted by me endpoint' do
    user = User.create!(name: 'Login teste', email: 'login-test@example.com', password: 'secret123')
    post '/login', params: { email: user.email, password: 'secret123' }, as: :json
    assert_response :success
    get '/me', headers: { 'Authorization' => "Bearer #{response.parsed_body['token']}" }
    assert_response :success
    assert_equal user.id, response.parsed_body['id']
  end
end
