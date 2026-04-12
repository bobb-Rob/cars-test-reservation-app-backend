require 'rails_helper'

RSpec.describe Car, type: :model do
  def build_car(overrides = {})
    Car.new({
      model: 'Civic',
      brand: 'Honda',
      year_released: DateTime.new(2020),
      featured_image: 'img.jpg'
    }.merge(overrides))
  end

  describe 'validations' do
    it 'is valid with required attributes' do
      expect(build_car).to be_valid
    end

    it 'validates presence of model' do
      expect(build_car(model: nil)).not_to be_valid
    end

    it 'validates presence of brand' do
      expect(build_car(brand: nil)).not_to be_valid
    end

    it 'validates presence of year_released' do
      expect(build_car(year_released: nil)).not_to be_valid
    end

    it 'validates presence of featured_image' do
      expect(build_car(featured_image: nil)).not_to be_valid
    end
  end

  describe 'scopes' do
    let!(:sedan) do
      Car.create!(model: 'Corolla', brand: 'Toyota', year_released: DateTime.new(2021),
                  featured_image: 'img.jpg', category: 'sedan', price_per_day: 50)
    end
    let!(:suv) do
      Car.create!(model: 'RAV4', brand: 'Toyota', year_released: DateTime.new(2022),
                  featured_image: 'img.jpg', category: 'suv', price_per_day: 80)
    end
    let!(:expensive) do
      Car.create!(model: 'S-Class', brand: 'Mercedes', year_released: DateTime.new(2023),
                  featured_image: 'img.jpg', category: 'sedan', price_per_day: 200)
    end

    it '.by_brand filters by brand' do
      expect(Car.by_brand('Toyota').pluck(:brand)).to all(eq('Toyota'))
    end

    it '.by_category filters by category' do
      ids = Car.by_category('sedan').pluck(:id)
      expect(ids).to include(sedan.id, expensive.id)
      expect(ids).not_to include(suv.id)
    end

    it '.min_price filters cars with price >= value' do
      ids = Car.min_price(80).pluck(:id)
      expect(ids).to include(suv.id, expensive.id)
      expect(ids).not_to include(sedan.id)
    end

    it '.max_price filters cars with price <= value' do
      ids = Car.max_price(80).pluck(:id)
      expect(ids).to include(sedan.id, suv.id)
      expect(ids).not_to include(expensive.id)
    end

    it '.available_between excludes cars with conflicting active reservations' do
      user = User.create!(name: 'Tester', email: 'tester@example.com', password: 'password123')
      Reservation.create!(user: user, car: sedan, city: 'Nairobi',
                          start_date: Date.today + 5, end_date: Date.today + 10)

      ids = Car.available_between(Date.today + 7, Date.today + 9).pluck(:id)
      expect(ids).not_to include(sedan.id)
      expect(ids).to include(suv.id, expensive.id)
    end

    it '.available_between includes cars whose reservations are cancelled' do
      user = User.create!(name: 'Tester2', email: 'tester2@example.com', password: 'password123')
      res = Reservation.create!(user: user, car: sedan, city: 'Nairobi',
                                start_date: Date.today + 5, end_date: Date.today + 10)
      res.cancel!

      ids = Car.available_between(Date.today + 7, Date.today + 9).pluck(:id)
      expect(ids).to include(sedan.id)
    end
  end

  describe 'associations' do
    it 'has many reservations' do
      assoc = Car.reflect_on_association(:reservations)
      expect(assoc.macro).to eq(:has_many)
    end
  end
end
