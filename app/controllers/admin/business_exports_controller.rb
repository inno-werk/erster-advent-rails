class Admin::BusinessExportsController < Admin::BaseController
  before_action :prepare_export

  def show
  end

  def download
    send_data @export.to_xlsx,
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment",
      filename: "geschaefte-#{Date.current.iso8601}.xlsx"
  end

  private

  def prepare_export
    @export = BusinessExport.new(sort: params[:sort], status: params[:status])
    response.headers["Cache-Control"] = "no-store, private"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end
end
