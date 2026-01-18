class PortfolioController < ApplicationController
  def index
    render inertia: true
  end
end
