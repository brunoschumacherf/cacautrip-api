require 'net/http'
require 'json'

class SupportResponder
  def self.call(message)
    url = ENV['SUPPORT_AI_URL']
    if url.present?
      uri = URI(url)
      raise 'Configure SUPPORT_AI_URL com HTTPS' unless uri.scheme == 'https'
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{ENV['SUPPORT_AI_TOKEN']}" if ENV['SUPPORT_AI_TOKEN'].present?
      request.body = { message: message, context: 'Suporte do Cacautrip. Não invente reservas, cobranças ou condições de segurança.' }.to_json
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 20) { |http| http.request(request) }
      raise 'Serviço de IA indisponível' unless response.is_a?(Net::HTTPSuccess)
      reply = JSON.parse(response.body).fetch('reply')
      return { reply: reply.to_s.truncate(8000), mode: 'ai', human_available: true }
    end
    text = case message.downcase
    when /pix|cart[aã]o|pagamento/ then 'Em Reservas, pague após o aceite do profissional. Escolha Pix ou cartão para concluir o pagamento.'
    when /cancel/ then 'Abra Reservas e selecione Cancelar antes da conclusão. Pagamentos aprovados recebem solicitação de estorno.'
    when /carteira|saldo|repasse/ then 'O pagamento gera saldo pendente na carteira. Após concluir o serviço, o valor líquido fica disponível para saque.'
    when /gov|documento|cadastro/ then 'No Perfil, autentique Gov.br, preencha o cadastro profissional e acompanhe a aprovação de documentos pela administração.'
    else 'Posso ajudar com reservas, pagamentos, carteira e cadastro. Para dúvidas sobre seu atendimento, abra um chamado humano abaixo.'
    end
    { reply: text, mode: 'local_help', human_available: true }
  rescue StandardError
    { reply: 'O serviço de IA está indisponível. Abra um chamado para atendimento humano.', mode: 'unavailable', human_available: true }
  end
end

