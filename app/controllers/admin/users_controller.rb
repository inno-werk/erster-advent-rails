class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [ :show, :update ]
  before_action :require_superadmin!, only: [ :new, :create, :update ]

  def index
    @role = list_choice(:role, [ 0, 1, 2 ])
    @confirmation = list_choice(:confirmation, %w[confirmed pending])
    scope = search_list(User.active.left_joins(:business), "users.name", "users.email", "businesses.business_name", "users.business_name")
    scope = scope.where(role: @role) if @role
    scope = scope.where.not(confirmed_at: nil) if @confirmation == "confirmed"
    scope = scope.where(confirmed_at: nil) if @confirmation == "pending"
    @users = paginate_list(scope.includes(:business).order(id: :asc))
  end

  def show
    prepare_details
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
    if @user.with_lock { @user.update(role_params) }
      redirect_to admin_user_path(@user), status: :see_other
    else
      @user.restore_attributes([ :role ])
      prepare_details
      render :show, status: :unprocessable_entity
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
      redirect_to admin_users_path, notice: "Benutzer wurde deaktiviert.", status: :see_other
    else
      redirect_to admin_users_path, alert: "Benutzer konnte nicht deaktiviert werden.", status: :see_other
    end
  end

  private

  def prepare_details
    @business = @user.business
    @participations = @user.participations.includes(:upgrades).order(year: :desc).to_a
    @current_participation = @participations.find { |participation| participation.year == EventConfiguration.year }
    @print_orders = @user.print_orders.includes(items: :print_product).order(year: :desc)
  end

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
