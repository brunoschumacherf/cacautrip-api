class WalletsController < ApplicationController
  before_action :authenticate_user!

  def show
    entries = @current_user.wallet_entries.order(created_at: :desc)
    render json: { available: entries.where(status: 'available').sum(:amount), pending: entries.where(status: 'pending').sum(:amount),
      gross: Booking.where(id: entries.where(kind: 'earning').where.not(status: 'cancelled').select(:booking_id)).sum(:total_amount),
      fees: Booking.where(id: entries.where(kind: 'earning').where.not(status: 'cancelled').select(:booking_id)).sum(:fee_amount),
      entries: entries.limit(200), payments: @current_user.bookings.where.not(payment_method: nil).order(created_at: :desc).map(&:details) }
  end

  def payout
    return render_error('Autentique sua conta Gov.br antes de solicitar um saque', :forbidden) unless @current_user.gov_verified?
    reference = params[:reference].to_s
    return render_error('Referência de saque inválida') unless reference.match?(/\A[a-zA-Z0-9-]{12,100}\z/)
    destination = payout_destination
    return render_error('Preencha os dados da conta de destino') unless destination
    @current_user.with_lock do
      previous = @current_user.wallet_entries.find_by(reference: reference)
      return render json: { message: 'Saque solicitado.', entry: previous } if previous
      balance = @current_user.wallet_entries.where(status: 'available').sum(:amount)
      amount = params[:amount].present? ? (BigDecimal(params[:amount].to_s.tr(',', '.')) rescue nil) : balance
      return render_error('Informe um valor disponível para saque') unless amount && amount.positive? && amount <= balance
      entry = @current_user.wallet_entries.create!(kind: 'payout', amount: -amount, status: 'available', reference: reference,
        metadata: { destination: destination, receipt_status: 'completed', requested_at: Time.current.iso8601 })
      render json: { message: 'Saque solicitado com sucesso.', entry: entry }
    end
  end

  private

  def payout_destination
    case params[:destination_type]
    when 'gov_cpf'
      { type: 'gov_cpf', label: 'CPF vinculado à conta Gov.br' }
    when 'pix_key'
      key = params[:pix_key].to_s.strip
      return if key.blank? || key.length > 180 || !ActiveModel::Type::Boolean.new.cast(params[:same_holder])
      { type: 'pix_key', label: "Chave Pix ••••#{key.last(4)}", same_holder: true }
    when 'bank_transfer'
      bank, agency, account = params.values_at(:bank, :agency, :account).map { |value| value.to_s.strip }
      return if [bank, agency, account].any?(&:blank?) || !ActiveModel::Type::Boolean.new.cast(params[:same_holder])
      { type: 'bank_transfer', label: "#{bank.truncate(60)} · Agência ••#{agency.last(2)} · Conta ••••#{account.last(4)}", same_holder: true }
    end
  end
end
