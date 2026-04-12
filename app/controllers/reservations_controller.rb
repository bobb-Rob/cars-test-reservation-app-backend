class ReservationsController < ApplicationController
  def index
    if current_user
      @reservations = case params[:filter]
                      when 'upcoming' then current_user.reservations.upcoming.includes(:car)
                      when 'past' then current_user.reservations.past.includes(:car)
                      when 'active' then current_user.reservations.active.includes(:car)
                      else current_user.reservations.includes(:car)
                      end
      render json: { code: 200, reservations: @reservations }, status: :ok
    else
      render json: { code: 401,
                     message: 'You need to sign in or sign up before continuing.' }, status: :unauthorized
    end
  end

  def show
    @reservation = current_user.reservations.includes(:car).find(params[:id])
    render json: { code: 200, reservation: @reservation }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { code: 404, message: 'Reservation not found' }, status: :not_found
  end

  def create
    @reservation = current_user.reservations.new(reservation_params)
    if @reservation.save
      render json: { code: 200,
                     reservation: @reservation,
                     message: 'Reservation created' }, status: :ok
    else
      render json: { code: 400,
                     message: 'Reservation not created',
                     error: @reservation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def cancel
    @reservation = current_user.reservations.active.find(params[:id])
    if @reservation.cancel!
      render json: { code: 200, reservation: @reservation, message: 'Reservation cancelled' }, status: :ok
    else
      render json: { code: 400, message: 'Reservation could not be cancelled',
                     error: @reservation.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { code: 404, message: 'Active reservation not found' }, status: :not_found
  end

  def destroy
    @reservation = current_user.reservations.find(params[:id])
    if @reservation.destroy
      render json: { code: 200, reservation: @reservation,
                     message: 'Reservation deleted' }, status: :ok
    else
      render json: { code: 400, reservation: @reservation,
                     message: 'Reservation not deleted',
                     error: @reservation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def reservation_params
    params.require(:reservation).permit(:car_id, :user_id, :reservation_date,
                                        :start_date, :end_date, :city)
  end
end
