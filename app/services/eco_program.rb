class EcoProgram
  class Invalid < StandardError; end

  def self.claim(user, code)
    code = code.to_s.strip.upcase
    raise Invalid, 'Informe o código recebido no ponto de coleta.' if code.blank? || code.length > 100
    user.with_lock do
      entry = EcoCollectionCode.find_by(code: code)
      raise Invalid, 'Código não encontrado.' unless entry
      entry.with_lock do
        return entry if entry.claimed_by_id == user.id && entry.claimed_at
        raise Invalid, 'Este código já foi utilizado.' if entry.claimed_at
        raise Invalid, 'Este código não está mais disponível.' if entry.voided_at || entry.expires_at <= Time.current || !entry.eco_collection_point.active?
        entry.update!(claimed_by: user, claimed_at: Time.current)
        user.update!(eco_points: user.eco_points + entry.points)
        EcoPointEntry.create!(user: user, eco_collection_code: entry, amount: entry.points, description: "Coleta em #{entry.eco_collection_point.name}")
        Notification.create!(user: user, title: 'Você ganhou pontos verdes!', body: "#{entry.points} pontos pela sua entrega. Confira os benefícios disponíveis.", kind: 'sustainability', target: 'sustentabilidade')
      end
      entry
    end
  end

  def self.redeem(user, reward_id, request_key)
    raise Invalid, 'Reabra a tela e tente resgatar novamente.' unless request_key.to_s.match?(/\A[a-zA-Z0-9_-]{12,100}\z/)
    user.with_lock do
      previous = user.eco_redemptions.find_by(request_key: request_key)
      if previous
        raise Invalid, 'Esta solicitação já foi utilizada para outro benefício.' unless previous.eco_reward_id.to_s == reward_id.to_s
        return previous
      end
      reward = EcoReward.find(reward_id)
      reward.with_lock do
        raise Invalid, 'Este benefício não está mais disponível.' unless EcoReward.available.exists?(reward.id)
        raise Invalid, 'Você ainda não possui pontos suficientes.' if user.eco_points < reward.points_cost
        benefit = reward.benefit_snapshot
        # Termos congelados: edições futuras no catálogo não alteram um cupom já resgatado.
        voucher = user.eco_redemptions.create!(eco_reward: reward, benefit: benefit, points_cost: reward.points_cost,
          expires_at: [reward.expires_at, 30.days.from_now].compact.min, request_key: request_key)
        user.update!(eco_points: user.eco_points - reward.points_cost)
        reward.update!(stock: reward.stock - 1) unless reward.stock.nil?
        EcoPointEntry.create!(user: user, eco_redemption: voucher, amount: -reward.points_cost, description: "Resgate: #{reward.title}")
        voucher
      end
    end
  end

  def self.use_partner(voucher, staff)
    voucher.with_lock do
      raise Invalid, 'Este cupom não é para uso em estabelecimentos.' unless voucher.benefit['scope'] == 'partner'
      raise Invalid, 'Este cupom já foi usado ou expirou.' unless voucher.status == 'available' && voucher.expires_at.future?
      voucher.update!(status: 'used', used_at: Time.current, validated_by: staff)
      Notification.create!(user: voucher.user, title: 'Benefício utilizado', body: "Seu cupom #{voucher.benefit['title']} foi validado pela equipe.", kind: 'sustainability', target: 'sustentabilidade')
    end
  end
end
