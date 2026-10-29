require 'test_helper'

class CompletedFlowsTest < ActionDispatch::IntegrationTest
  setup do
    @tourist = User.create!(name: 'Turista teste', email: 'tourist-flow@example.com', password: 'secret123')
    @pro = User.create!(name: 'Profissional teste', email: 'pro-flow@example.com', password: 'secret123')
    @headers = headers_for(@tourist)
    @pro_headers = headers_for(@pro)
  end

  test 'gov mock is explicit and guide requires description and image' do
    payload = { specialization: 'Trilhas', languages: 'Português', description: 'Passeios na Mata Atlântica', image_url: 'https://example.com/guia.jpg' }
    post '/professional_profiles/guide', params: payload, headers: @pro_headers, as: :json
    assert_response :forbidden
    post '/me/verify_gov', headers: @pro_headers, as: :json
    assert_response :success
    assert @pro.reload.gov_verified
    post '/professional_profiles/guide', params: payload, headers: @pro_headers, as: :json
    assert_response :success
    assert_equal payload[:description], @pro.reload.guide_profile.description
    post '/professional_profiles/guide', params: payload.merge(image_url: ''), headers: @pro_headers, as: :json
    assert_response :unprocessable_entity
  end

  test 'pix is approved only on fourth poll and cannot be paid before acceptance' do
    booking = create_booking
    post "/bookings/#{booking.id}/pay", params: { payment_method: 'pix' }, headers: @headers, as: :json
    assert_response :conflict
    patch "/bookings/#{booking.id}/respond", params: { action_type: 'accept' }, headers: @pro_headers, as: :json
    assert_response :success
    post "/bookings/#{booking.id}/pay", params: { payment_method: 'pix' }, headers: @headers, as: :json
    assert_response :success
    3.times do
      post "/bookings/#{booking.id}/payment_status", headers: @headers, as: :json
      assert_equal 'pending', response.parsed_body.dig('booking', 'payment_status')
    end
    post "/bookings/#{booking.id}/payment_status", headers: @headers, as: :json
    assert_equal 'approved', response.parsed_body.dig('booking', 'payment_status')
    assert_equal 'confirmed', booking.reload.status
    post "/bookings/#{booking.id}/payment_status", headers: @headers, as: :json
    assert_equal 4, booking.reload.payment_polls
  end

  test 'card accepts arbitrary details and only tourist pays' do
    booking = create_booking
    booking.update!(status: 'approved_waiting_payment')
    post "/bookings/#{booking.id}/pay", params: { payment_method: 'credit_card' }, headers: @pro_headers, as: :json
    assert_response :not_found
    post "/bookings/#{booking.id}/pay", params: { payment_method: 'credit_card', card: 'anything' }, headers: @headers, as: :json
    assert_response :success
    assert_equal 'approved', booking.reload.payment_status
  end

  test 'messages persist and are only accessible to participants' do
    @pro.update!(gov_verified: true)
    guide = @pro.create_guide_profile!(specialization: 'Praias', languages: 'Português', description: 'Passeios locais', image_url: 'https://example.com/guia.jpg')
    post '/conversations', params: { professional_type: 'Guia', professional_id: guide.id }, headers: @headers, as: :json
    assert_response :success
    id = response.parsed_body['id']
    post "/conversations/#{id}/messages", params: { content: 'Olá, onde vamos nos encontrar?' }, headers: @headers, as: :json
    assert_response :created
    get "/conversations/#{id}/messages", headers: @pro_headers
    assert_equal 'Olá, onde vamos nos encontrar?', response.parsed_body.last['content']
    outsider = User.create!(name: 'Outro', email: 'other-flow@example.com', password: 'secret123')
    get "/conversations/#{id}/messages", headers: headers_for(outsider)
    assert_response :not_found
    post "/conversations/#{id}/messages", params: { content: '  ' }, headers: @headers, as: :json
    assert_response :unprocessable_entity
  end

  private

  def headers_for(user)
    { 'Authorization' => "Bearer #{Rails.application.message_verifier('session').generate(user.id, purpose: 'login')}" }
  end

  def create_booking
    @pro.update!(gov_verified: true)
    driver = @pro.create_driver_profile!(vehicle_model: 'Duster', license_plate: 'ABC1234', capacity: 4)
    post '/bookings', params: { booking: { service_type: 'Motorista', service_id: driver.id, total_amount: 200, date: '2026-11-05 09:00', meeting_point: 'Hotel' } }, headers: @headers, as: :json
    assert_response :created
    Booking.find(response.parsed_body.dig('booking', 'id'))
  end
end
