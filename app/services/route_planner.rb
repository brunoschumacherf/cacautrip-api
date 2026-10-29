class RoutePlanner
  def initialize(options = {})
    @options = options.to_h.symbolize_keys
  end

  def call
    accessible = ActiveModel::Type::Boolean.new.cast(@options[:accessible])
    people = @options[:people].to_i.clamp(1, 100)
    budget = @options[:budget].present? ? BigDecimal(@options[:budget].to_s.tr(',', '.')) : nil
    minutes = (@options[:minutes].presence || 480).to_i.clamp(30, 10080)
    candidates = Destination.where(active: true)
    candidates = candidates.where(accessible: true) if accessible
    if @options[:destination_ids].present?
      requested_ids = Array(@options[:destination_ids]).map(&:to_i)
      indexed = candidates.where(id: requested_ids).index_by(&:id)
      candidates = requested_ids.filter_map { |id| indexed[id] }
    else
      region = @options[:destination].to_s.strip
      candidates = candidates.where('city ILIKE ?', "%#{Destination.sanitize_sql_like(region)}%") if region.present?
      interests = @options[:interests].to_s.downcase.split(/[,\s]+/).reject(&:blank?)
      candidates = candidates.to_a.sort_by do |place|
        text = "#{place.category} #{place.description} #{place.name}".downcase
        score = interests.count { |interest| text.include?(interest) }
        [-score, place.price.to_f, place.id]
      end
    end
    guide = professional(GuideProfile, accessible)
    driver = professional(DriverProfile, accessible, people)
    guide_cost = ActiveModel::Type::Boolean.new.cast(@options[:include_guide]) && guide ? guide.price : BigDecimal('0')
    driver_cost = ActiveModel::Type::Boolean.new.cast(@options[:include_driver]) && driver ? driver.price : BigDecimal('0')
    places_budget = budget && [budget - guide_cost - driver_cost, BigDecimal('0')].max
    selected, elapsed, cost = [], 0, BigDecimal('0')
    candidates.each do |place|
      duration = [place.duration_minutes.to_i, 15].max
      travel = selected.empty? ? 0 : 20
      price = place.price * people
      next if @options[:destination_ids].blank? && (elapsed + duration + travel > minutes || (places_budget && cost + price > places_budget))
      selected << place
      cost += price
      elapsed += duration + travel
    end
    total = cost + guide_cost + driver_cost
    # A estimativa de deslocamento é explicita, sem inventar uma trilha navegável.
    cursor = 0
    stops = selected.map do |place|
      start = cursor
      cursor += [place.duration_minutes.to_i, 15].max + 20
      place.as_json.merge('start_after_minutes' => start, 'estimated_cost' => (place.price * people).to_f)
    end
    { destinations: stops, destination_ids: selected.map(&:id), duration_minutes: elapsed,
      costs: { places: cost.to_f, guide: guide_cost.to_f, driver: driver_cost.to_f, total: total.to_f },
      guide: guide && ProfessionalDirectory.serialize(guide), driver: driver && ProfessionalDirectory.serialize(driver),
      within_budget: budget.nil? || total <= budget, budget: budget&.to_f,
      warnings: [ ('Nenhuma opção cabe nos filtros informados.' if selected.empty?),
        ('O total com guia e transporte ultrapassa o orçamento.' if budget && total > budget),
        ('Alguns locais exigem acompanhamento de guia.' if selected.any?(&:guide_required)),
        'Deslocamentos e preços são estimativas. Confirme a disponibilidade antes de reservar.' ].compact }
  end

  private

  def professional(klass, accessible, people = nil)
    scope = klass.joins(:user).where(users: { gov_verified: true, suspended: false }, moderation_status: 'published', available: true)
    scope = scope.where(accessible: true) if accessible
    scope = scope.where('capacity >= ?', people) if klass == DriverProfile && people
    region = @options[:destination].to_s.strip
    scope = scope.where('region ILIKE ?', "%#{klass.sanitize_sql_like(region)}%") if region.present?
    scope.order(price: :asc).first
  end
end
