require 'rails_helper'

RSpec.describe 'Reservations API', type: :request do
  let(:user) do
    User.create!(name: 'Test User', email: 'res_user@example.com', password: 'password123')
  end
  let(:car) do
    Car.create!(model: 'Civic', brand: 'Honda', year_released: DateTime.new(2020),
                featured_image: 'img.jpg')
  end
  let(:other_car) do
    Car.create!(model: 'Fit', brand: 'Honda', year_released: DateTime.new(2021),
                featured_image: 'img2.jpg')
  end

  # Helper to get a JWT token for authenticated requests
  def auth_headers(u = user)
    post '/users/sign_in', params: { user: { email: u.email, password: 'password123' } },
                           as: :json
    token = response.headers['Authorization']
    { 'Authorization' => token }
  end

  describe 'GET /reservations' do
    let!(:upcoming_res) do
      Reservation.create!(user: user, car: car, city: 'Nairobi',
                          start_date: Date.today + 5, end_date: Date.today + 7)
    end
    let!(:past_res) do
      Reservation.create!(user: user, car: other_car, city: 'Lagos',
                          start_date: Date.today - 10, end_date: Date.today - 5)
    end

    it 'returns all reservations for the current user' do
      get '/reservations', headers: auth_headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      ids = json['reservations'].map { |r| r['id'] }
      expect(ids).to include(upcoming_res.id, past_res.id)
    end

    it 'returns only upcoming reservations with filter=upcoming' do
      get '/reservations', params: { filter: 'upcoming' }, headers: auth_headers
      json = JSON.parse(response.body)
      ids = json['reservations'].map { |r| r['id'] }
      expect(ids).to include(upcoming_res.id)
      expect(ids).not_to include(past_res.id)
    end

    it 'returns only past reservations with filter=past' do
      get '/reservations', params: { filter: 'past' }, headers: auth_headers
      json = JSON.parse(response.body)
      ids = json['reservations'].map { |r| r['id'] }
      expect(ids).to include(past_res.id)
      expect(ids).not_to include(upcoming_res.id)
    end
  end

  describe 'GET /reservations/:id' do
    let!(:reservation) do
      Reservation.create!(user: user, car: car, city: 'Nairobi',
                          start_date: Date.today + 5, end_date: Date.today + 7)
    end

    it 'returns the reservation detail' do
      get "/reservations/#{reservation.id}", headers: auth_headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['reservation']['id']).to eq(reservation.id)
    end

    it 'returns 404 for a reservation belonging to another user' do
      other_user = User.create!(name: 'Other', email: 'other@example.com', password: 'password123')
      other_res = Reservation.create!(user: other_user, car: other_car, city: 'Accra',
                                      start_date: Date.today + 5, end_date: Date.today + 7)
      get "/reservations/#{other_res.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /reservations' do
    it 'creates a reservation successfully' do
      post '/reservations',
           params: { reservation: { car_id: car.id, city: 'Nairobi',
                                    start_date: Date.today + 10, end_date: Date.today + 12 } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Reservation created')
    end

    it 'rejects a reservation with conflicting dates' do
      Reservation.create!(user: user, car: car, city: 'Nairobi',
                          start_date: Date.today + 10, end_date: Date.today + 15)

      post '/reservations',
           params: { reservation: { car_id: car.id, city: 'Lagos',
                                    start_date: Date.today + 12, end_date: Date.today + 14 } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to include('Car is already reserved for the selected dates')
    end

    it 'rejects a reservation with end_date before start_date' do
      post '/reservations',
           params: { reservation: { car_id: car.id, city: 'Nairobi',
                                    start_date: Date.today + 10, end_date: Date.today + 5 } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /reservations/:id/cancel' do
    let!(:reservation) do
      Reservation.create!(user: user, car: car, city: 'Nairobi',
                          start_date: Date.today + 5, end_date: Date.today + 7)
    end

    it 'cancels an active reservation' do
      patch "/reservations/#{reservation.id}/cancel", headers: auth_headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Reservation cancelled')
      expect(reservation.reload.status).to eq('cancelled')
      expect(reservation.reload.cancelled_at).to be_present
    end

    it 'returns 404 when cancelling an already-cancelled reservation' do
      reservation.cancel!
      patch "/reservations/#{reservation.id}/cancel", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it 'allows the same car to be reserved after cancellation' do
      reservation.cancel!
      post '/reservations',
           params: { reservation: { car_id: car.id, city: 'Nairobi',
                                    start_date: Date.today + 5, end_date: Date.today + 7 } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'DELETE /reservations/:id' do
    let!(:reservation) do
      Reservation.create!(user: user, car: car, city: 'Nairobi',
                          start_date: Date.today + 5, end_date: Date.today + 7)
    end

    it 'hard-deletes a reservation' do
      delete "/reservations/#{reservation.id}", headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(Reservation.find_by(id: reservation.id)).to be_nil
    end
  end
end
