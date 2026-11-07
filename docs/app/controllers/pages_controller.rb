class PagesController < ApplicationController
  def landing
    render layout: "landing"
  end

  def show
    @page = Docs.page(params[:slug]) or raise ActionController::RoutingError, "No page #{params[:slug]}"
    render @page.slug
  end

  def llms
  end

  def not_found
    render status: :not_found
  end
end
