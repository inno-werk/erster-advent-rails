class App::Setup::TestPaymentsController < App::Setup::BaseController
  include TestPaymentProcessing
  layout "checkout"

  def show
    prepare_test_payment(continue_setup: true)
  end
end
