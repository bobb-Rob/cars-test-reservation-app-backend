class CarsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show availability]

  def index
    @cars = apply_filters(Car.all)
    @cars = apply_availability(@cars)
    @cars = apply_sort(@cars)

    render json: { code: 200, cars: @cars, user: current_user }
  end

  def show
    @car = Car.find(params[:id])
    render json: { code: 200, car: @car }
  rescue ActiveRecord::RecordNotFound
    render json: { code: 404, message: 'Car not found' }, status: :not_found
  end

  def availability
    @car = Car.find(params[:id])
    start_date = params[:start_date]
    end_date = params[:end_date]

    unless start_date.present? && end_date.present?
      return render json: { code: 422, message: 'start_date and end_date are required' },
                    status: :unprocessable_entity
    end

    available = !Reservation.active
      .where(car_id: @car.id)
      .where('start_date <= ? AND end_date >= ?', end_date, start_date)
      .exists?

    render json: { code: 200, car_id: @car.id, available:,
                   start_date:, end_date: }
  rescue ActiveRecord::RecordNotFound
    render json: { code: 404, message: 'Car not found' }, status: :not_found
  end

  def create
    @car = Car.new(car_params)
    if @car.save
      render json: { code: 200, car: @car, notice: 'Car was successfully created.', status: :created }
    else
      render json: { car: @car.errors, notice: 'Car could not be created', status: :unprocessable_entity }
    end
  end

  def destroy
    @car = Car.find(params[:id])
    if @car.destroy
      render json: { code: 200, car: @car, notice: 'Car was successfully deleted.', status: :ok }
    else
      render json: { code: 500, car: @car, notice: 'car was not successsfully deleted', status: :failed }
    end
  end

  private

  def apply_filters(cars)
    cars = cars.by_brand(params[:brand]) if params[:brand].present?
    cars = cars.by_model(params[:model]) if params[:model].present?
    cars = cars.by_category(params[:category]) if params[:category].present?
    cars = cars.min_price(params[:min_price]) if params[:min_price].present?
    cars = cars.max_price(params[:max_price]) if params[:max_price].present?
    cars
  end

  def apply_availability(cars)
    return cars unless params[:start_date].present? && params[:end_date].present?

    cars.available_between(params[:start_date], params[:end_date])
  end

  def apply_sort(cars)
    case params[:sort]
    when 'price_asc' then cars.order(price_per_day: :asc)
    when 'price_desc' then cars.order(price_per_day: :desc)
    when 'newest' then cars.order(created_at: :desc)
    else cars
    end
  end

  def car_params
    params.require(:car).permit(:model, :brand, :specifications, :year_released, :featured_image,
                                :price_per_day, :category)
  end
end
