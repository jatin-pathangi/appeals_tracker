class AppealsController < ApplicationController
  PER_PAGE = 20

  def index
    @cities = City.order(:name)
    @selected_city = City.find_by(id: params[:city_id]) || @cities.first
    @current_page = [ params.fetch(:page, 1).to_i, 1 ].max

    if @selected_city
      base = @selected_city.housing_appeals.order(filed_date: :desc)
      @total_count = base.count
      @total_pages = [ (@total_count / PER_PAGE.to_f).ceil, 1 ].max
      @current_page = [ @current_page, @total_pages ].min
      @appeals = base.offset((@current_page - 1) * PER_PAGE).limit(PER_PAGE)
    else
      @appeals = HousingAppeal.none
      @total_count = 0
      @total_pages = 1
    end
  end
end
