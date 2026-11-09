class PagesController < ApplicationController
  def show
    @page = Docs.page(params[:slug]) or raise ActionController::RoutingError, "No page #{params[:slug]}"
    render @page.template
  end

  def llms
  end

  def not_found
    render status: :not_found
  end
end
