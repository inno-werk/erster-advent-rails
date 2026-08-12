class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [ :show, :update ]
  before_action :require_superadmin!, only: [ :new, :create, :update ]

  def index
    @q = params[:q].to_s.strip
    scope = @q.present? ? User.search(@q) : User.all
    scope = scope.includes(:business)
    scope = scope.active.order(id: :asc)
    @pagy, @users = pagy(scope, items: params[:per]&.to_i || 10)
  end

  def show
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.password = SecureRandom.hex(12)
    @user.skip_confirmation!

    if @user.save
      @user.send_reset_password_instructions
      redirect_to admin_user_path(@user), notice: "Benutzer wurde erstellt. Eine E-Mail zum Setzen des Passworts wurde versendet."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @user.update(role_params)
      redirect_to admin_user_path(@user), notice: "Rolle wurde aktualisiert."
    else
      redirect_to admin_user_path(@user), alert: @user.errors.full_messages.to_sentence, status: :unprocessable_entity
    end
  end

  def impersonate
    user = User.find(params[:id])

    if user.deleted?
      redirect_to admin_user_path(user), alert: "Dieser Benutzer ist deaktiviert und kann nicht angemeldet werden.", status: :see_other and return
    end

    if user == current_user
      redirect_to admin_user_path(user), notice: "Sie sind bereits als dieser Benutzer angemeldet.", status: :see_other and return
    end

    session[:admin_impersonator_id] = current_user.id
    sign_in(:user, user)
    redirect_to app_mystore_path, notice: "Sie sind jetzt als #{user.email} angemeldet.", status: :see_other
  end

  def destroy
    @user = User.find(params[:id])

    if @user == current_user
      redirect_to admin_users_path, alert: "Sie können sich nicht selbst löschen.", status: :see_other and return
    end

    if @user.update(deleted: true)
      redirect_to admin_users_path, notice: "Benutzer wurde gelöscht.", status: :see_other
    else
      redirect_to admin_users_path, alert: "Benutzer konnte nicht gelöscht werden.", status: :see_other
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def require_superadmin!
    unless current_user&.superadmin?
      redirect_to admin_users_path, alert: "Nur Superadmins können diese Aktion ausführen."
    end
  end

  def user_params
    params.require(:user).permit(:email, :name, :role)
  end

  def role_params
    params.require(:user).permit(:role)
  end
end
