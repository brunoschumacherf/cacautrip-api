require 'csv'
module Backoffice
  class ReportsController < BaseController
    before_action :require_administrator!

    def index
      @from = parse_date(params[:from], 30.days.ago.to_date)
      @to = parse_date(params[:to], Date.current)
      @from, @to = @to, @from if @from > @to
      @from = @to - 365 if @to - @from > 365
      range = @from.in_time_zone.beginning_of_day..@to.in_time_zone.end_of_day
      bookings = Booking.where(created_at: range)
      @totals = { 'Reservas no período' => bookings.count, 'Serviços concluídos' => bookings.where(status: 'completed').count,
        'Novos usuários' => User.where(created_at: range).count, 'Avaliações publicadas' => Review.where(created_at: range, hidden: false).count }
      @gross = bookings.where(payment_status: 'approved').sum(:total_amount)
      @fees = bookings.where(payment_status: 'approved').sum(:fee_amount)
      @series = {
        'Reservas por dia' => bookings.group('DATE(created_at)').order(Arel.sql('DATE(created_at)')).count,
        'Reservas por situação' => bookings.group(:status).count,
        'Serviços contratados' => bookings.group(:service_type).count,
        'Roteiros por destino' => Route.where(created_at: range).group(:destination).count,
        'Vagas contratadas por região da trilha' => bookings.joins(trail_departure: :trail).group('trails.region').sum(:people)
      }
      respond_to do |format|
        format.html
        format.csv do
          audit!('reports.export', nil, from: @from.to_s, to: @to.to_s)
          csv = CSV.generate(col_sep: ';', force_quotes: true) do |output|
            output << ['Indicador', 'Grupo', 'Quantidade / valor']
            @totals.each { |label, count| output << [label, '', count] }
            output << ['Total aprovado (R$)', '', @gross.to_s('F')]
            output << ['Comissões (R$)', '', @fees.to_s('F')]
            @series.each { |label, rows| rows.each { |group, count| output << [label, safe_cell(group), count] } }
          end
          send_data "\uFEFF#{csv}", filename: "cacautrip-relatorios-#{@from}-#{@to}.csv", type: 'text/csv; charset=utf-8'
        end
      end
    end

    private

    def parse_date(value, fallback)
      value.present? ? Date.iso8601(value) : fallback
    rescue Date::Error
      fallback
    end

    def safe_cell(value)
      text = value.to_s
      text.match?(/\A[=+@\-\t\r]/) ? "'#{text}" : text
    end
  end
end
