class PostsController < ApplicationController
  def index
    @posts = Post.all
  end

  def show
    @post = Post.find(params[:slug])
  end

  def feed
    @posts = Post.all
  end
end
