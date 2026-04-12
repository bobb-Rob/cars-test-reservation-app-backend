require 'rails_helper'

RSpec.describe 'Cars API', type: :request do
  let!(:sedan) do
    Car.create!(model: 'Corolla', brand: 'Toyota', year_released: DateTime.new(2021),
                featured_image: 'img.jpg', category: 'sedan', price_per_day: 50)
  end
  let!(:suv) do
    Car.create!(model: 'RAV4', brand: 'Toyota', year_released: DateTime.new(2022),
                featured_image: 'img.jpg', category: 'suv', price_per_day: 80)
  end
  let!(:luxury) do
    Car.create!(model: 'S-Class', brand: 'Mercedes', year_released: DateTime.new(2023),
                featured_image: 'img.jpg', category: 'sedan', price_per_day: 200)
  end

  describe 'GET /cars' do
    it 'returns all cars when no filters are applied' do
      get '/cars'
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['cars'].length).to be >= 3
    end

    it 'filters by brand' do
      get '/cars', params: { brand: 'Toyota' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['cars'].map { |c| c['brand'] }).to all(eq('Toyota'))
    end

    it 'filters by category' do
      get '/cars', params: { category: 'sedan' }
      json = JSON.parse(response.body)
      ids = json['cars'].map { |c| c['id'] }
      expect(ids).to include(sedan['id'] || sedan.id, luxury['id'] || luxury.id)
      expect(ids).not_to include(suv['id'] || suv.id)
    end

    it 'filters by max_price' do
      get '/cars', params: { max_price: 80 }
      json = JSON.parse(response.body)
      prices = json['cars'].map { |c| c['price_per_day']&.to_f }
      expect(prices.compact).to all(be <= 80)
    end

    it 'sorts by price_asc' do
      get '/cars', params: { sort: 'price_asc' }
      json = JSON.parse(response.body)
      prices = json['cars'].map { |c| c['price_per_day']&.to_f }.compact
      expect(prices).to eq(prices.sort)
    end

    it 'sorts by price_desc' do
      get '/cars', params: { sort: 'price_desc' }
      json = JSON.parse(response.body)
      prices = json['cars'].map { |c| c['price_per_day']&.to_f }.compact
      expect(prices).to eq(prices.sort.reverse)
    end

    it 'filters by availability window, excluding cars with conflicting reservations' do
      user = User.create!(name: 'User', email: 'user@example.com', password: 'password123')
      Reservation.create!(user: user, car: sedan, city: 'Nairobi',
                          start_date: Date.today + 5, end_date: Date.today + 10)

      get '/cars', params: { start_date: Date.today + 6, end_date: Date.today + 8 }
      json = JSON.parse(response.body)
      ids = json['cars'].map { |c| c['id'] }
      expect(ids).not_to include(sedan.id)
    end
  end

  describe 'GET /cars/:id' do
    it 'returns a specific car' do
      get "/cars/#{sedan.id}"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['car']['id']).to eq(sedan.id)
    end

    it 'returns 404 for missing car' do
      get '/cars/99999'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /cars/:id/availability' do
    it 'returns available=true when car has no conflicting reservations' do
      get "/cars/#{sedan.id}/availability",
          params: { start_date: Date.today + 20, end_date: Date.today + 25 }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['available']).to be true
    end

    it 'returns available=false when car has conflicting reservation' do
      user = User.create!(name: 'User2', email: 'user2@example.com', password: 'password123')
      Reservation.create!(user: user, car: sedan, city: 'Nairobi',
                          start_date: Date.today + 5, end_date: Date.today + 10)

      get "/cars/#{sedan.id}/availability",
          params: { start_date: Date.today + 7, end_date: Date.today + 9 }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['available']).to be false
    end

    it 'returns 422 when dates are missing' do
      get "/cars/#{sedan.id}/availability"
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
