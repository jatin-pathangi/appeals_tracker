class AppealsController < ApplicationController
  PER_PAGE = 20

  def index
    @cities = City.order(:name)
    @selected_city = City.find_by(id: params[:city_id]) || @cities.first
    @current_page = [ params.fetch(:page, 1).to_i, 1 ].max

    if @selected_city
      all_appeals = @selected_city.housing_appeals.order(filed_date: :desc).to_a

      # Group by address; order is preserved (most-recent appeal first per group,
      # groups appear in the order of their most-recent appeal).
      grouped = all_appeals.group_by do |a|
        a.project_address.presence || a.project_name.presence || "Address unknown"
      end.to_a  # [[address, [appeals...]], ...]

      @total_appeals_count = all_appeals.size
      @total_count  = grouped.size   # paginate by address group, not individual appeals
      @total_pages  = [ (@total_count / PER_PAGE.to_f).ceil, 1 ].max
      @current_page = [ @current_page, @total_pages ].min
      @grouped_appeals = grouped.slice((@current_page - 1) * PER_PAGE, PER_PAGE) || []
    else
      @grouped_appeals     = []
      @total_count         = 0
      @total_appeals_count = 0
      @total_pages         = 1
    end
  end
end
