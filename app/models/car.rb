class Car < ApplicationRecord
  has_many :reservations, foreign_key: :car_id, dependent: :destroy

  validates :model, :brand, :year_released, :featured_image, presence: true

  scope :by_brand, ->(brand) { where(brand:) }
  scope :by_model, ->(model) { where(model:) }
  scope :by_category, ->(category) { where(category:) }
  scope :max_price, ->(price) { where('price_per_day <= ?', price) }
  scope :min_price, ->(price) { where('price_per_day >= ?', price) }

  scope :available_between, lambda { |start_date, end_date|
    reserved_ids = Reservation.active
      .where('start_date <= ? AND end_date >= ?', end_date, start_date)
      .select(:car_id)
    where.not(id: reserved_ids)
  }
end
