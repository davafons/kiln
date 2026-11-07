class PagesController < ApplicationController
  def home; end
  def about; end
  def guide; end
  def search; end
  def private_page; end
  def contact; end

  def health
    render json: { status: "ok", posts: Post.all.size }
  end

  def not_found
    render status: :not_found
  end
end
