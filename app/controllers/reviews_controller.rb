class ReviewsController < ApplicationController
  before_action :authenticate_user!

  def create
    booking = @current_user.bookings.find(params[:booking_id])
    review = Review.create!(booking: booking, user: @current_user, rating: params[:rating], comment: params[:comment])
    render json: review, status: :created
  end

  def report
    type = params[:subject_type]
    klass = { 'Review' => Review, 'User' => User, 'Message' => Message }[type]
    return render_error('Tipo de denúncia inválido') unless klass
    record = klass.find(params[:subject_id])
    if type == 'Message'
      chat = record.conversation
      return render_error('Conversa não acessível', :forbidden) unless [chat.tourist_id, chat.guide_id, chat.driver_id].include?(@current_user.id)
    end
    report = Report.create!(user: @current_user, subject_type: type, subject_id: record.id, reason: params[:reason])
    render json: report, status: :created
  end
end
