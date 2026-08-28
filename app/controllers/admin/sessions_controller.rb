class Admin::SessionsController < Users::SessionsController
  def create
    self.resource = warden.authenticate!(auth_options)
    unless resource.adminish?
      sign_out(resource_name)
      clean_up_passwords(resource)
      flash.now[:alert] = "Dieses Konto hat keinen Zugang zum Adminbereich."
      return render :new, status: :unprocessable_entity
    end

    set_flash_message!(:notice, :signed_in)
    sign_in(resource_name, resource)
    respond_with resource, location: after_sign_in_path_for(resource)
  end

  def after_sign_in_path_for(resource)
    return super unless resource.adminish?

    stored_location_for(resource)
    admin_root_path
  end
end
