require 'rails_helper'

RSpec.describe Reservation, type: :model do
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com', password: 'password123') }
  let(:car) do
    Car.create!(model: 'Civic', brand: 'Honda', year_released: DateTime.new(2020), featured_image: 'img.jpg')
  end

  def build_reservation(overrides = {})
    Reservation.new({
      user: user,
      car: car,
      city: 'Nairobi',
      start_date: Date.today + 10,
      end_date: Date.today + 12
    }.merge(overrides))
  end

  describe 'validations' do
    it 'is valid with required attributes' do
      expect(build_reservation).to be_valid
    end

    it 'validates the presence of a car' do
      reservation = Reservation.new(car: nil)
      expect(reservation).not_to be_valid
    end

    it 'validates the presence of a user' do
      reservation = Reservation.new(user: nil)
      expect(reservation).not_to be_valid
    end

    it 'validates the presence of city' do
      expect(build_reservation(city: nil)).not_to be_valid
    end

    it 'validates the presence of start_date' do
      expect(build_reservation(start_date: nil)).not_to be_valid
    end

    it 'validates the presence of end_date' do
      expect(build_reservation(end_date: nil)).not_to be_valid
    end

    it 'rejects end_date before start_date' do
      r = build_reservation(start_date: Date.today + 5, end_date: Date.today + 3)
      expect(r).not_to be_valid
      expect(r.errors[:end_date]).to include('must be on or after start date')
    end

    it 'allows same start_date and end_date (single-day reservation)' do
      r = build_reservation(start_date: Date.today + 5, end_date: Date.today + 5)
      expect(r).to be_valid
    end
  end

  describe 'conflict detection' do
    let!(:existing) do
      r = build_reservation(start_date: Date.today + 10, end_date: Date.today + 15)
      r.save!
      r
    end

    it 'rejects a reservation that overlaps (starts inside existing)' do
      r = build_reservation(start_date: Date.today + 12, end_date: Date.today + 18)
      expect(r).not_to be_valid
      expect(r.errors[:base]).to include('Car is already reserved for the selected dates')
    end

    it 'rejects a reservation that overlaps (ends inside existing)' do
      r = build_reservation(start_date: Date.today + 8, end_date: Date.today + 11)
      expect(r).not_to be_valid
    end

    it 'rejects a reservation that fully contains existing' do
      r = build_reservation(start_date: Date.today + 9, end_date: Date.today + 16)
      expect(r).not_to be_valid
    end

    it 'allows a reservation that starts the day after existing ends' do
      r = build_reservation(start_date: Date.today + 16, end_date: Date.today + 20)
      expect(r).to be_valid
    end

    it 'allows a reservation that ends the day before existing starts' do
      r = build_reservation(start_date: Date.today + 5, end_date: Date.today + 9)
      expect(r).to be_valid
    end

    it 'allows a conflicting date range if the existing reservation is cancelled' do
      existing.cancel!
      r = build_reservation(start_date: Date.today + 12, end_date: Date.today + 14)
      expect(r).to be_valid
    end
  end

  describe '#cancel!' do
    it 'sets status to cancelled and records cancelled_at' do
      r = build_reservation
      r.save!
      expect { r.cancel! }.to change { r.status }.from('active').to('cancelled')
      expect(r.cancelled_at).to be_present
    end
  end

  describe 'scopes' do
    let!(:upcoming_res) do
      r = build_reservation(start_date: Date.today + 5, end_date: Date.today + 7)
      r.save!
      r
    end
    let!(:past_res) do
      r = build_reservation(start_date: Date.today - 10, end_date: Date.today - 5)
      r.save!
      r
    end
    let!(:cancelled_res) do
      r = build_reservation(start_date: Date.today + 20, end_date: Date.today + 22)
      r.save!
      r.cancel!
      r
    end

    it '.active returns only active reservations' do
      active_ids = Reservation.active.pluck(:id)
      expect(active_ids).to include(upcoming_res.id, past_res.id)
      expect(active_ids).not_to include(cancelled_res.id)
    end

    it '.upcoming returns active reservations with end_date >= today' do
      ids = Reservation.upcoming.pluck(:id)
      expect(ids).to include(upcoming_res.id)
      expect(ids).not_to include(past_res.id, cancelled_res.id)
    end

    it '.past returns active reservations with end_date < today' do
      ids = Reservation.past.pluck(:id)
      expect(ids).to include(past_res.id)
      expect(ids).not_to include(upcoming_res.id, cancelled_res.id)
    end
  end

  describe 'backward-compat: reservation_date populates start_date/end_date' do
    it 'derives start_date and end_date from reservation_date when not set' do
      date = Date.today + 30
      r = Reservation.new(user: user, car: car, city: 'Lagos', reservation_date: date)
      r.valid?
      expect(r.start_date).to eq(date)
      expect(r.end_date).to eq(date)
    end
  end

  describe 'associations' do
    it 'belongs to a car' do
      assoc = Reservation.reflect_on_association(:car)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it 'belongs to a user' do
      assoc = Reservation.reflect_on_association(:user)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end
end
