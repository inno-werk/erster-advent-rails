class App::BaseController < ApplicationController
  before_action :authenticate_user!
  helper_method :current_participation, :setup_flow?
  layout :store_layout
  def index
    redirect_to app_participation_path
  end

  private

  def setup_flow?
    params[:setup] == "1"
  end

  def store_layout
    setup_flow? ? "setup" : "app"
  end

  def current_participation
    @current_participation ||= current_user.current_participation
  end
end
