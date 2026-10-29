class RoutesController < ApplicationController
  before_action :authenticate_user!

  def index
    render json: @current_user.routes.order(created_at: :desc)
  end

  def show
    render json: @current_user.routes.find(params[:id])
  end

  def suggest
    render json: RoutePlanner.new(planner_params).call
  rescue ArgumentError
    render_error('Informe orçamento e duração válidos')
  end

  def create
    route = @current_user.routes.new(route_params)
    prepare(route)
    route.save!
    render json: route, status: :created
  end

  def update
    route = @current_user.routes.find(params[:id])
    route.assign_attributes(route_params)
    prepare(route)
    route.save!
    render json: route
  end

  def share
    route = @current_user.routes.find(params[:id])
    route.update!(shared_token: route.shared_token.presence || SecureRandom.urlsafe_base64(32))
    render json: { token: route.shared_token }
  end

  def unshare
    @current_user.routes.find(params[:id]).update!(shared_token: nil)
    head :no_content
  end

  def destroy
    @current_user.routes.find(params[:id]).destroy!
    head :no_content
  end

  private

  def prepare(route)
    preferences = route.preferences.to_h
    if Array(preferences['destination_ids']).empty?
      route.total_estimated_cost = 0
      preferences['itinerary'] = []
      route.preferences = preferences
      return
    end
    plan = RoutePlanner.new(preferences.merge(destination: route.destination, budget: route.budget)).call
    route.total_estimated_cost = plan[:costs][:total]
    route.preferences = preferences.merge('destination_ids' => plan[:destination_ids], 'itinerary' => plan[:destinations], 'costs' => plan[:costs], 'warnings' => plan[:warnings])
  end

  def planner_params
    params.permit(:destination, :budget, :minutes, :people, :interests, :accessible, :include_guide, :include_driver, destination_ids: [])
  end

  def route_params
    params.require(:route).permit(:title, :destination, :budget, preferences: [:notes, :accessible, :minutes, :people, :interests, :include_guide, :include_driver, destination_ids: []])
  end
end
