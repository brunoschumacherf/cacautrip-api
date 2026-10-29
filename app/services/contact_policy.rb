class ContactPolicy
  WORD_DIGITS = { 'zero' => '0', 'um' => '1', 'uma' => '1', 'dois' => '2', 'duas' => '2', 'tres' => '3', 'quatro' => '4', 'cinco' => '5', 'seis' => '6', 'sete' => '7', 'oito' => '8', 'nove' => '9' }.freeze

  def self.blocked?(content)
    text = ActiveSupport::Inflector.transliterate(content.to_s.unicode_normalize(:nfkc)).downcase.gsub(/\p{Cf}/, '')
    return true if text.match?(/(?:https?:\/\/|www\.|wa\.me|t\.me|whats\s*app|whatsapp|telegram|instagram|insta\b|\bzap\b|\barroba\b)/i)
    return true if text.match?(/[\w.+-]+\s*@\s*[\w.-]+\s*\.\s*[a-z]{2,}/i) || text.match?(/(?:\A|\s)@[\w.]{3,}/)
    return true if text.match?(/(?:[a-z0-9-]+\.)+(?:com|net|org|br|io)\b/i)
    # Datas e horários de passeio são permitidos; não confundir com telefone.
    numeric = text.gsub(/\b20\d{2}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\d|3[01])\b/, ' ')
      .gsub(/\b(?:0?[1-9]|[12]\d|3[01])\/(?:0?[1-9]|1[0-2])\/20\d{2}\b/, ' ')
      .gsub(/\b(?:[01]?\d|2[0-3])[:h][0-5]\d\b/, ' ')
      .gsub(/\b(?:zero|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove)\b/) { |word| WORD_DIGITS[word] }
    numeric.match?(/(?:\d[\s().+\-_\/,:;]*){8,}/) || numeric.scan(/\d/).length >= 10 || text.match?(/(?:me chama|me liga|me encontre|contato)\s+(?:no|pelo|por)\s+(?:telefone|celular|email|e-mail)/)
  end
end
