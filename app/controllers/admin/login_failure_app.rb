class Admin::LoginFailureApp < Devise::FailureApp
  def redirect_url
    Rails.application.routes.url_helpers.admin_login_path(locale: request.path_parameters[:locale])
  end
end
