class App::TestPaymentsController < App::BaseController
  include TestPaymentProcessing
  layout "checkout"

  def show
    prepare_test_payment(continue_setup: false)
  end
end
