class Reservation < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :car, optional: true

  validates :city, :start_date, :end_date, presence: true
  validate :end_date_after_start_date
  validate :no_conflicting_reservation

  scope :active, -> { where(status: 'active') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :upcoming, -> { active.where('end_date >= ?', Date.today) }
  scope :past, -> { active.where('end_date < ?', Date.today) }

  before_validation :set_dates_from_reservation_date

  def cancel!
    update!(status: 'cancelled', cancelled_at: Time.current)
  end

  private

  # Backward-compat: if only reservation_date is given, derive start_date/end_date from it
  def set_dates_from_reservation_date
    return unless reservation_date.present?

    self.start_date ||= reservation_date
    self.end_date ||= reservation_date
  end

  def end_date_after_start_date
    return unless start_date && end_date

    errors.add(:end_date, 'must be on or after start date') if end_date < start_date
  end

  def no_conflicting_reservation
    return unless start_date && end_date && car_id

    conflicts = Reservation.active
      .where(car_id:)
      .where.not(id:)
      .where('start_date <= ? AND end_date >= ?', end_date, start_date)
    errors.add(:base, 'Car is already reserved for the selected dates') if conflicts.exists?
  end
end
