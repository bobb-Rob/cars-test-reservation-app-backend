class AddDateRangeAndStatusToReservations < ActiveRecord::Migration[7.0]
  def up
    add_column :reservations, :start_date, :date
    add_column :reservations, :end_date, :date
    add_column :reservations, :status, :string, default: 'active', null: false
    add_column :reservations, :cancelled_at, :datetime

    # Backfill existing records: use reservation_date as both start and end
    execute("UPDATE reservations SET start_date = reservation_date, end_date = reservation_date")

    change_column_null :reservations, :start_date, false
    change_column_null :reservations, :end_date, false

    # Remove the overly-restrictive unique index on [user_id, car_id]
    # (a user should be able to reserve the same car on different dates)
    remove_index :reservations, name: "index_reservations_on_user_id_and_car_id"

    add_index :reservations, :status
  end

  def down
    add_index :reservations, [:user_id, :car_id], unique: true, name: "index_reservations_on_user_id_and_car_id"
    remove_index :reservations, :status
    remove_column :reservations, :cancelled_at
    remove_column :reservations, :status
    remove_column :reservations, :end_date
    remove_column :reservations, :start_date
  end
end
