# Bank details and letterhead for participation invoices: read-only overview
# in the «Bankverbindung» menu, edited on a separate form. The invoice page
# (step 2) uses the same form and returns there after saving.
class Admin::InvoiceSettingsController < Admin::BaseController
  before_action :load_setting

  def show
  end

  def edit
  end

  def update
    if @setting.update(setting_params)
      redirect_to return_path, notice: "Die Bankverbindung wurde gespeichert.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_setting
    @setting = InvoiceSetting.current
  end

  def setting_params
    params.require(:invoice_setting).permit(:creditor_name, :street, :building_number, :postal_code, :town, :country, :iban, :bank_name, :letterhead)
  end

  # Only fixed internal destinations, never a submitted URL.
  def return_path
    params[:return_to] == "invoice_run" ? new_admin_invoice_run_path : admin_invoice_setting_path
  end
end
