class App::BaseController < ApplicationController
  before_action :authenticate_user!
  helper_method :current_participation
  layout "app"
  def index
    redirect_to app_participation_path
  end

  private

  def current_participation
    @current_participation ||= current_user.current_participation
  end
end
