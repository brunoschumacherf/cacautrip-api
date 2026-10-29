class RecommendationsController < ApplicationController
  before_action :authenticate_user!

  def create
    message = params[:message].to_s.strip.truncate(4000)
    options = params.permit(:destination, :budget, :minutes, :people, :interests, :accessible, :include_guide, :include_driver).to_h
    amount = message.match(/(?:R\$|reais|or[cç]amento)\s*(\d+(?:[.,]\d+)?)/i) || message.match(/(\d+(?:[.,]\d+)?)\s*reais/i)
    options['budget'] ||= amount[1].tr(',', '.') if amount
    options['destination'] ||= @current_user.preferences.to_h['region']
    options['interests'] ||= message.presence || @current_user.preferences.to_h['interests']
    options['accessible'] = @current_user.preferences.to_h['accessible'] unless options.key?('accessible')
    plan = RoutePlanner.new(options).call
    render json: { mode: 'catalog_recommendation', reply: "Encontrei #{plan[:destinations].length} opções compatíveis com os filtros. Escolha os lugares e confira a estimativa antes de reservar.", plan: plan }
  rescue ArgumentError
    render_error('Informe um orçamento válido')
  end
end
