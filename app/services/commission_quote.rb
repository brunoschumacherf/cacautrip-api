class CommissionQuote
  def self.call(amount)
    gross = BigDecimal(amount.to_s.tr(',', '.')).round(2)
    raise ArgumentError, 'Valor inválido' unless gross.finite? && gross >= 0 && gross <= 99999999
    rate = PlatformSetting.commission
    fee = (gross * rate).round(2)
    { gross: gross.to_f, rate: rate.to_f, percent: (rate * 100).to_f, fee: fee.to_f, net: (gross - fee).to_f, estimated: true }
  end
end
