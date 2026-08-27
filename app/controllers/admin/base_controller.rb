class Admin::BaseController < ApplicationController
  before_action :require_admin!

  layout "admin"

  private

  def list_choice(key, choices, default: nil)
    value = params[key].to_s
    choices.map(&:to_s).include?(value) ? value : default
  end

  def list_year
    value = params[:year].to_s
    value.match?(/\A\d{4}\z/) && (2000..9999).cover?(value.to_i) ? value.to_i : EventConfiguration.year
  end

  def search_list(scope, *columns)
    @q = params[:q].to_s.strip
    return scope if @q.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@q)}%"
    scope.where(columns.map { |column| "#{column} ILIKE :query" }.join(" OR "), query: pattern)
  end

  def paginate_list(scope)
    @per = list_choice(:per, [ 10, 20, 50 ], default: "20").to_i
    page = [ params[:page].to_i, 1 ].max
    @pagy, records = pagy(scope, items: @per, page: page)
    records
  rescue Pagy::OverflowError => error
    @pagy, records = pagy(scope, items: @per, page: error.pagy.last)
    records
  end

  def require_admin!
    unless current_user&.adminish?
      redirect_to root_path, alert: "Not authorized"
    end
  end
end
