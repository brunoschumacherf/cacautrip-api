# Contrato OpenAPI estático. ruby script/build_openapi.rb (sem Rails/banco).
require 'yaml'
require 'json'
ROOT = File.expand_path('..', __dir__)
load File.join(ROOT, 'app/services/backoffice/registry.rb')
def ref(x); {'$ref'=>"#/components/schemas/#{x}"}; end
def s(**x); {'type'=>'string'}.merge(x.transform_keys(&:to_s)); end
def i(**x); {'type'=>'integer','format'=>'int64'}.merge(x.transform_keys(&:to_s)); end
def n(**x); {'type'=>'number'}.merge(x.transform_keys(&:to_s)); end
def b(**x); {'type'=>'boolean'}.merge(x.transform_keys(&:to_s)); end
def a(x); {'type'=>'array','items'=>x}; end
def o(x={}, required=[]); h={'type'=>'object','properties'=>x}; h['required']=required unless required.empty?; h; end
def param(name, schema=s, desc='', location='query', required=false); {'name'=>name,'in'=>location,'required'=>required,'description'=>desc,'schema'=>schema}; end
def body(schema, example=nil, mime='application/json'); h={'schema'=>schema}; h['example']=example if example; {'required'=>true,'content'=>{mime=>h}}; end
def response(schema, desc='Operação realizada', mime='application/json'); h={'description'=>desc}; h['content']={mime=>{'schema'=>schema}} if schema; h; end
S={}; P={}; T={}
E={'400'=>'Parâmetro obrigatório ausente ou malformado','401'=>'Sessão inválida, ausente, expirada ou conta suspensa','403'=>'Permissão ou requisito de identidade não atendido','404'=>'Registro inexistente, não público ou fora do escopo','409'=>'Conflito de estado, duplicidade ou operação simultânea','410'=>'Prazo da reserva de trilha expirado','422'=>'Validação ou regra de negócio não atendida','429'=>'Limite de tentativas excedido; aguarde','503'=>'Serviço indisponível ou integração não configurada'}
def ep(verb,path,tag,title,desc='', input:nil, output:nil, code:200, auth: :bearer, query:[], errors:[], deprecated:false)
  pars=path.scan(/\{([^}]+)\}/).flatten.map{|x| param(x,%w[id booking_id trail_id departure_id professional_id].include?(x) ? i(minimum:1) : s,'Identificador limitado ao escopo descrito.','path',true)}+query
  security=case auth; when :public then []; when :optional then [{},{'bearerAuth'=>[]}]; when :staff then [{'staffSession'=>[]}]; else [{'bearerAuth'=>[]}]; end
  op={'operationId'=>"#{verb}_#{path.gsub(/[^a-zA-Z0-9]+/,'_').gsub(/^_|_$/,'')}",'summary'=>title,'description'=>desc,'tags'=>[tag],'security'=>security,'responses'=>{code.to_s=>response(output,code==201 ? 'Registro criado' : code==204 ? 'Concluído sem corpo' : 'Operação realizada')}}
  op['parameters']=pars unless pars.empty?; op['requestBody']=body(input) if input; op['deprecated']=true if deprecated
  err=errors.map(&:to_s); err|=['401'] if [:bearer,:optional].include?(auth); err|=['404'] if path.include?('{id}') || path.include?('{booking_id}')
  err.each{|x|op['responses'][x]=response(ref('Error'),E.fetch(x))}; (P[path]||={})[verb]=op; op
end
def html(verb,path,title,desc='',input:nil,query:[],admin:false)
  op=ep(verb,path,'Painel Rails (HTML)',title,"#{desc}\nAdminUser #{admin ? 'admin' : 'com as permissões descritas'}. HTML e cookie de sessão; não usa Bearer. Sem sessão redireciona a /gestao/entrar. Escritas exigem CSRF do formulário/meta csrf-token.",auth: :staff,query:query)
  op['requestBody']=body(input,nil,'application/x-www-form-urlencoded') if input
  if verb!='get'; (op['parameters']||=[])<<param('X-CSRF-Token',s,'Alternativa ao campo authenticity_token do formulário.','header'); end
  op['responses']={'200'=>response(s,'Página HTML','text/html'),'302'=>{'description'=>'Redirecionamento de sessão/navegação','headers'=>{'Location'=>{'schema'=>s}}},'303'=>{'description'=>'Redirecionamento após operação','headers'=>{'Location'=>{'schema'=>s}}},'403'=>response(s,'Papel sem acesso ou CSRF inválido','text/html'),'404'=>response(s,'Registro/área não encontrado','text/html'),'422'=>response(s,'Formulário com erros','text/html')}; op
end
File.read(File.join(ROOT,'db/schema.rb')).scan(/create_table "([^"]+)"[^\n]* do \|t\|\n(.*?)^  end/m).each do |table,block|
  fields={'id'=>i}
  block.each_line do |line|
    m=line.match(/t\.(\w+) "([^"]+)"(.*)/); next unless m
    type,name,opts=m.captures; next if %w[password_digest google_uid].include?(name)
    next unless %w[string text integer bigint boolean float decimal datetime date jsonb json].include?(type)
    h=case type; when 'integer','bigint' then i; when 'boolean' then b; when 'float' then n; when 'decimal' then {'oneOf'=>[n,s(pattern:'^-?[0-9]+(\\.[0-9]+)?$')],'description'=>'Decimal persistido pode ser string; valor calculado pode ser número.'}; when 'datetime' then s(format:'date-time'); when 'date' then s(format:'date'); when 'jsonb','json' then opts.include?('default: []') ? a({}) : o; else s; end
    h['nullable']=true unless opts.include?('null: false')||opts.include?('default:'); fields[name]=h
  end
  T[table]=fields
end
{'Destination'=>'destinations','Alert'=>'alerts','EmergencyPoint'=>'emergency_points','Route'=>'routes','TrailStop'=>'trail_stops','GuideRecord'=>'guide_profiles','DriverRecord'=>'driver_profiles','Message'=>'messages','WalletEntry'=>'wallet_entries','Review'=>'reviews','Report'=>'reports','Notification'=>'notifications','Subscription'=>'subscriptions','SubscriptionOrder'=>'subscription_orders','CollectionPoint'=>'eco_collection_points','EcoPartner'=>'eco_partners'}.each{|name,table|S[name]=o(T.fetch(table).dup)}
S['Decimal']={'oneOf'=>[n,s(pattern:'^-?[0-9]+(\\.[0-9]+)?$')],'description'=>'Decimal numérico ou string decimal, conforme serialização do Rails.'}
S['Error']=o('error'=>s,'errors'=>a(s)); S['MessageResult']=o('message'=>s)
S['Preferences']=o('interests'=>s,'accessible'=>b,'region'=>s,'notifications'=>b)
S['User']=o({'id'=>i,'name'=>s,'email'=>s(format:'email'),'gov_verified'=>b,'active_role'=>s(enum:%w[tourist guide driver]),'preferences'=>ref('Preferences'),'admin'=>b,'google_connected'=>b,'eco_points'=>i,'roles'=>a(s(enum:%w[tourist guide driver])),'guide_profile'=>{'allOf'=>[ref('GuideRecord')],'nullable'=>true},'driver_profile'=>{'allOf'=>[ref('DriverRecord')],'nullable'=>true}},%w[id name email])
S['AuthResult']=o({'message'=>s,'token'=>s(description:'Token Rails assinado de sete dias, não JWT.'),'user'=>ref('User')},%w[token user])
S['Commission']=o('gross'=>n,'rate'=>n,'percent'=>n(nullable:true),'fee'=>n,'net'=>n,'estimated'=>b)
extra={'name'=>s,'verified'=>b,'documents_verified'=>b,'rating'=>ref('Decimal'),'reviews_count'=>i,'reviews'=>a(ref('Review')),'plan'=>s(enum:%w[basic featured premium]),'trails_count'=>i,'starting_price'=>n(nullable:true)}
S['Professional']=o(T['guide_profiles'].merge(T['driver_profiles']).reject{|k,_|%w[document_reference license_plate].include?(k)}.merge(extra))
S['PrivateProfessional']=o(T['guide_profiles'].merge(T['driver_profiles']).merge(extra).merge('type'=>s(enum:%w[Guia Motorista]),'bookings_count'=>i,'completed_count'=>i,'gross'=>ref('Decimal'),'net'=>ref('Decimal')))
S['Departure']=o(T['trail_departures'].merge('available_seats'=>i,'unit_price'=>n,'price_mode'=>s(enum:%w[per_person group]),'ends_at'=>s(format:'date-time')))
S['Trail']=o(T['trails'].merge('stops'=>a(ref('TrailStop')),'departures'=>a(ref('Departure')),'guide'=>o('id'=>i,'user_id'=>i,'name'=>s,'image_url'=>s(nullable:true),'languages'=>s),'rating'=>n,'reviews_count'=>i,'reviews'=>a(ref('Review'))))
S['Booking']=o(T['bookings'].merge('professional'=>o,'provider_id'=>i(nullable:true),'tourist_name'=>s,'review'=>{'allOf'=>[ref('Review')],'nullable'=>true},'fee_rate'=>n,'itinerary'=>a(o),'hold_expired'=>b,'commission'=>ref('Commission'),'amount_due'=>n,'platform_net_amount'=>n))
S['BookingResult']=o({'booking'=>ref('Booking'),'pix_code'=>s,'message'=>s},['booking'])
S['Conversation']=o(T['conversations'].merge('name'=>s))
S['Catalog']=o('destinations'=>a(ref('Destination')),'alerts'=>a(ref('Alert')),'emergency_points'=>a(ref('EmergencyPoint')),'pagination'=>o('page'=>i,'per_page'=>i,'total'=>i,'total_pages'=>i,'has_previous'=>b,'has_next'=>b))
S['Plan']=o('destinations'=>a(o(T['destinations'].merge('start_after_minutes'=>i,'estimated_cost'=>n))),'destination_ids'=>a(i),'duration_minutes'=>i,'costs'=>o('places'=>n,'guide'=>n,'driver'=>n,'total'=>n),'guide'=>{'allOf'=>[ref('Professional')],'nullable'=>true},'driver'=>{'allOf'=>[ref('Professional')],'nullable'=>true},'within_budget'=>b,'budget'=>n(nullable:true),'warnings'=>a(s))
S['SupportTicket']=o('id'=>i,'status'=>s(enum:%w[ai open answered closed]),'subject'=>s,'created_at'=>s(format:'date-time'),'updated_at'=>s(format:'date-time'),'human_requested_at'=>s(format:'date-time',nullable:true),'assigned_name'=>s(nullable:true),'ai_responding'=>b)
S['SupportMessage']=o('id'=>i,'role'=>s(enum:%w[user assistant staff system]),'content'=>s,'sender_name'=>s(nullable:true),'created_at'=>s(format:'date-time'))
S['SupportConversation']=o(S['SupportTicket']['properties'].merge('messages'=>a(ref('SupportMessage')),'has_older'=>b))
S['Benefit']=o('title'=>s,'description'=>s(nullable:true),'scope'=>s(enum:%w[partner trail driver]),'discount_type'=>s(enum:%w[fixed percent]),'discount_value'=>n,'minimum_amount'=>n,'maximum_discount'=>n(nullable:true),'partner'=>{'type'=>'object','nullable'=>true,'properties'=>{'name'=>s,'city'=>s,'address'=>s}},'image_url'=>s(nullable:true))
S['EcoReward']=o(S['Benefit']['properties'].merge('id'=>i,'points_cost'=>i,'stock'=>i(nullable:true),'expires_at'=>s(format:'date-time',nullable:true)))
S['EcoVoucher']=o(T['eco_redemptions'].slice('id','code','status','points_cost','expires_at','used_at','booking_id').merge('benefit'=>ref('Benefit'),'expired'=>b))
S['Sustainability']=o('balance'=>i,'cities'=>a(s),'collection_points'=>a(ref('CollectionPoint')),'rewards'=>a(ref('EcoReward')),'vouchers'=>a(ref('EcoVoucher')),'history'=>a(o('id'=>i,'amount'=>i,'description'=>s,'created_at'=>s(format:'date-time'))))
S['Wallet']=o('available'=>ref('Decimal'),'pending'=>ref('Decimal'),'gross'=>ref('Decimal'),'fees'=>ref('Decimal'),'entries'=>a(ref('WalletEntry')),'payments'=>a(ref('Booking')))
S['SignupInput']=o({'name'=>s(example:'Ana Lima'),'email'=>s(format:'email',example:'ana@example.com'),'password'=>s(minLength:6,writeOnly:true),'password_confirmation'=>s(writeOnly:true)},%w[name email password])
S['LoginInput']=o({'email'=>s(format:'email'),'password'=>s(writeOnly:true)},%w[email password])
S['ProfileInput']=o('name'=>s,'email'=>s(format:'email'),'active_role'=>s(enum:%w[tourist guide driver]),'preferences'=>ref('Preferences'))
common={'region'=>s,'price'=>n(minimum:0),'available'=>b,'accessible'=>b,'services'=>s,'document_reference'=>s,'description'=>s,'image_url'=>s(format:'uri'),'availability'=>a(s(description:'Datas/horários oferecidos.'))}
S['GuideInput']=o(common.merge('specialization'=>s(example:'Ecoturismo e trilhas'),'languages'=>s(example:'Português, Inglês')),%w[specialization languages description image_url document_reference])
S['DriverInput']=o(common.merge('vehicle_model'=>s(example:'Renault Duster'),'license_plate'=>s(example:'ABC1D23'),'capacity'=>i(minimum:1,maximum:60)),%w[vehicle_model license_plate document_reference])
planner={'destination'=>s(example:'Ilhéus'),'budget'=>n(minimum:0),'minutes'=>i(description:'Padrão 480; limitado internamente a 30..10080.'),'people'=>i(description:'Limitado a 1..100.'),'interests'=>s,'accessible'=>b,'include_guide'=>b,'include_driver'=>b,'destination_ids'=>a(i)}
S['PlannerInput']=o(planner)
S['RouteInput']=o({'route'=>o('title'=>s,'destination'=>s,'budget'=>n,'preferences'=>o(planner.reject{|k,_|%w[destination budget].include?(k)}.merge('notes'=>s)))},['route'])
S['TrailStopInput']=o('id'=>i,'name'=>s(maxLength:300),'address'=>s(maxLength:300),'description'=>s,'kind'=>s(enum:%w[meeting visit break finish]),'position'=>i(minimum:0),'duration_minutes'=>i(minimum:0,maximum:1440),'latitude'=>n(minimum:-90,maximum:90),'longitude'=>n(minimum:-180,maximum:180),'optional'=>b,'_destroy'=>b)
trail={'title'=>s(maxLength:150),'description'=>s,'region'=>s,'image_url'=>s(format:'uri'),'difficulty'=>s(enum:%w[easy moderate hard]),'route_mode'=>s(enum:%w[ordered flexible]),'duration_minutes'=>i(minimum:1,maximum:10080),'distance_km'=>n(minimum:0),'price'=>n(minimum:0,exclusiveMinimum:true),'price_mode'=>s(enum:%w[per_person group]),'minimum_age'=>i(minimum:0,maximum:100),'accessible'=>b,'included'=>s,'not_included'=>s,'what_to_bring'=>s,'safety_notes'=>s,'cancellation_policy'=>s,'status'=>s(enum:%w[draft published archived]),'stops_attributes'=>a(ref('TrailStopInput'))}
S['TrailInput']=o({'trail'=>o(trail)},['trail'])
S['DepartureInput']=o({'departure'=>o('starts_at'=>s(format:'date-time'),'capacity'=>i(minimum:1,maximum:100),'price_override'=>n(nullable:true,minimum:0,exclusiveMinimum:true),'meeting_point'=>s,'notes'=>s),'starts_at_list'=>a(s(format:'date-time'))},['departure'])
S['BookingInput']=o({'booking'=>o({'service_type'=>s(enum:%w[Motorista Passeio Parceiro]),'service_id'=>i,'date'=>s(example:'2026-11-20 09:00'),'meeting_point'=>s,'dropoff_point'=>s,'people'=>i(minimum:1,maximum:100),'route_id'=>i,'conditions'=>s,'total_amount'=>n(minimum:0,exclusiveMinimum:true),'pickup_latitude'=>n,'pickup_longitude'=>n,'dropoff_latitude'=>n,'dropoff_longitude'=>n},%w[service_type service_id date meeting_point])},['booking'])
S['PayInput']=o({'payment_method'=>s(enum:%w[pix credit_card]),'redemption_id'=>i(nullable:true,description:'Cupom da conta; null remove desconto. Valor calculado no servidor.')},['payment_method'])
S['PayoutInput']=o({'reference'=>s(minLength:12,maxLength:100,pattern:'^[a-zA-Z0-9-]+$'),'amount'=>n(minimum:0,exclusiveMinimum:true),'destination_type'=>s(enum:%w[gov_cpf pix_key bank_transfer]),'pix_key'=>s(maxLength:180),'bank'=>s,'agency'=>s,'account'=>s,'same_holder'=>b(description:'true para chave Pix/transferência de mesma titularidade Gov.br.')},%w[reference destination_type])
S['SubscriptionInput']=o({'professional_type'=>s(enum:%w[guide driver]),'plan'=>s(enum:%w[basic featured premium]),'auto_renew'=>b(default:false)},%w[professional_type plan])
S['SupportInput']=o({'message'=>s(minLength:1,maxLength:4000,example:'Preciso de ajuda com minha reserva.')},['message'])
ep('post','/signup','Autenticação','Cadastrar turista','Campos na raiz ou em authentication. Conta começa com gov_verified=false. Não aceita admin, user_id ou papéis profissionais. GET /me fornece o perfil completo.',auth: :public,input:ref('SignupInput'),output:ref('AuthResult'),code:201,errors:[400,422,429])
ep('post','/login','Autenticação','Entrar com e-mail e senha','Campos na raiz ou em authentication. E-mail normalizado; sessão Rails assinada de sete dias. Conta suspensa não entra.',auth: :public,input:ref('LoginInput'),output:ref('AuthResult'),errors:[401,429])
S['User']['properties']['avatar_url']=s(nullable:true,description:'Caminho da foto de perfil; resolver em relação à origem da API. Nulo quando não há foto.')
ep('get','/me','Conta e privacidade','Consultar minha conta e papéis',output:ref('User'))
ep('patch','/me','Conta e privacidade','Atualizar dados, preferências ou papel ativo','guide/driver exigem Gov.br verificado e o perfil correspondente. Não altera admin, google_uid ou verificação de identidade.',input:ref('ProfileInput'),output:ref('User'),errors:[403,422])
ep('patch','/me/avatar','Conta e privacidade','Enviar ou substituir foto de perfil','Multipart: campo photo, arquivo JPG/PNG/WebP com até 2 MiB. Verifica o conteúdo do arquivo. Retorna o perfil atualizado com avatar_url. Não altera a foto do anúncio profissional.',input:o({'photo'=>s(format:'binary')},['photo']),output:ref('User'),errors:[422])
P['/me/avatar']['patch']['requestBody']['content']['multipart/form-data']=P['/me/avatar']['patch']['requestBody']['content'].delete('application/json')
P['/me/avatar']['patch']['responses']['413']=response(ref('Error'),'Foto maior que 2 MiB')
ep('delete','/me/avatar','Conta e privacidade','Remover minha foto de perfil','Retorna o perfil atualizado com avatar_url nulo.',output:ref('User'))
ep('get','/profile_photos/{id}','Conta e privacidade','Exibir foto por identificador assinado','URL retornada em avatar_url. ID é token assinado, não ID numérico. A versão deve coincidir; fotos removidas/trocadas ou usuários suspensos retornam 404. Resposta binária com cache privado de cinco minutos.',auth: :public,query:[param('version',s,'Versão da foto.','query',true)])
P['/profile_photos/{id}']['get']['parameters'].find{|item|item['name']=='id'}['schema']=s
P['/profile_photos/{id}']['get']['responses']['200']={'description'=>'Imagem de perfil','content'=>%w[image/jpeg image/png image/webp].to_h{|mime|[mime,{'schema'=>s(format:'binary')}]}}

ep('post','/me/verify_gov','Conta e privacidade','Verificar Gov.br no fluxo de demonstração','Simulado: define gov_verified=true. Ainda não verifica CPF/documentos com provedor real. Aprovação profissional é separada.',output:o('user'=>ref('User'),'verification_status'=>s(enum:['verified']),'message'=>s))
ep('get','/privacy/export','Conta e privacidade','Exportar meus dados pessoais','Somente dados da conta autenticada; inclui suporte, sustentabilidade, cupons e extrato de pontos.',output:o('exported_at'=>s(format:'date-time'),'profile'=>ref('User'),'routes'=>a(ref('Route')),'bookings'=>a(ref('Booking')),'wallet'=>a(ref('WalletEntry')),'subscriptions'=>a(ref('Subscription')),'reviews'=>a(ref('Review')),'tickets'=>a(ref('SupportConversation')),'eco_vouchers'=>a(ref('EcoVoucher')),'eco_points_history'=>a(o)))
ep('post','/privacy/deletion_request','Conta e privacidade','Solicitar exclusão/anonimização','Abre chamado humano. Não exclui imediatamente: equipe analisa titularidade, retenção e pendências.',output:o('message'=>s,'ticket_id'=>i),code:201)
ep('post','/auth/google/start','Google OAuth','Iniciar cadastro/login ou vinculação Google','Sem Bearer inicia login/cadastro; com Bearer vincula a conta autenticada. redirect_uri deve constar exatamente em GOOGLE_APP_REDIRECT_URIS. Requer GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_CALLBACK_URL e GOOGLE_APP_REDIRECT_URIS. Guarde exchange_secret localmente e abra authorization_url. Tentativa válida por dez minutos.',auth: :optional,input:o({'redirect_uri'=>s(example:'http://localhost:8081/google-callback')},['redirect_uri']),output:o('authorization_url'=>s(format:'uri'),'exchange_secret'=>s,'flow_id'=>i),errors:[422,429,503])
cb=ep('get','/auth/google/callback','Google OAuth','Receber retorno do Google','Callback do navegador. Verifica ID token e redireciona ao app com code temporário e flow; erros: cancelled, account_exists, invalid_identity. Não vincula contas apenas pelo e-mail. O code retornado ao app é diferente do código OAuth do Google.',auth: :public,query:[param('state',s,'State do fluxo.','query',true),param('code',s,'Código OAuth obrigatório no sucesso.'),param('error',s,'Cancelamento/erro do Google.')],errors:[401])
cb['responses'].delete('200'); cb['responses']['302']={'description'=>'Retorno autorizado ao app com código válido por dois minutos, uso único, ou erro.','headers'=>{'Location'=>{'schema'=>s}}}
ep('post','/auth/google/finish','Google OAuth','Trocar código temporário por sessão','Exige flow_id, code retornado ao app e segredo guardado no início. Consome uma única vez. Novas contas são turistas sem Gov.br verificado.',auth: :public,input:o({'flow_id'=>i,'code'=>s,'exchange_secret'=>s},%w[flow_id code exchange_secret]),output:ref('AuthResult'),errors:[401,403])
ep('get','/health','Infraestrutura','Consultar Rails e PostgreSQL',auth: :public,output:o('status'=>s(enum:%w[ok unavailable]),'database'=>s(enum:%w[available unavailable])),errors:[503])
ep('get','/catalog','Catálogo e destinos','Consultar destinos, alertas e apoio','Paginação opt-in com page/per_page: padrão 6, máximo 30; resposta inclui pagination. Sem ambos retorna destinos completos para mapas/roteiros. Páginas fora do intervalo são ajustadas. Coordenadas juntas ordenam todo o conjunto por distância antes do recorte e adicionam distance_km. Sem coordenadas ordena por nome/id. Alertas e apoio não são paginados.',auth: :public,output:ref('Catalog'),query:[param('q',s,'Nome, cidade ou descrição.'),param('category',s,'Categoria exata.'),param('accessible',b),param('budget',n,'Preço máximo por destino.'),param('latitude',n),param('longitude',n),param('page',i(minimum:1)),param('per_page',i(minimum:1,maximum:30,default:6))])
S['DestinationBanner']=o('id'=>s,'destination_id'=>i(nullable:true),'name'=>s,'city'=>s,'category'=>s,'caption'=>s,'image_url'=>s(format:'uri'),'source'=>s(enum:%w[catalog wikimedia]),'source_url'=>s(format:'uri'),'author'=>s,'license'=>s,'license_url'=>s(format:'uri',nullable:true))
ep('get','/catalog/highlights','Catálogo e destinos','Consultar banners e fotos da cidade','Seleciona cidade cadastrada por nome ou pela posição aproximada do destino mais próximo; padrão Ilhéus ou primeira cidade. Até seis banners, independentes da paginação. Fotos do catálogo têm prioridade; Wikimedia Commons complementa com fotos da cidade, autoria, licença e fonte. Não importa destinos nem atribui uma foto da cidade a um ponto turístico específico. Cache positivo de 6h e negativo de 15min. Sem fotos, banners fica vazio e o app mostra uma chamada visual.',auth: :public,output:o('city'=>s(nullable:true),'cities'=>a(s),'banners'=>a(ref('DestinationBanner'))),query:[param('city',s),param('latitude',n),param('longitude',n)])

ep('get','/destinations/{id}','Catálogo e destinos','Consultar destino ativo',auth: :public,output:ref('Destination'))
filters=[param('q',s),param('region',s),param('specialization',s),param('services',s),param('available',b),param('accessible',b),param('max_price',n),param('min_rating',n(minimum:0,maximum:5))]
%w[guides drivers].each do |kind|
  ep('get',"/professional_profiles/#{kind}",'Perfis profissionais',"Listar #{kind=='guides' ? 'guias' : 'motoristas'} públicos",'Exige publicação, Gov.br verificado e conta não suspensa. available=true limita a disponíveis. Ordena por destaque da assinatura, avaliação e preço. Sem paginação. Omissão de referência documental e placa nos dados públicos.',auth: :public,output:a(ref('Professional')),query:filters+(kind=='drivers' ? [param('people',i(minimum:1),'Capacidade mínima.')] : []))
end
op=ep('get','/professional_profiles/{kind}/{id}','Perfis profissionais','Consultar perfil público','kind=guide ou driver. Somente publicado, com Gov.br verificado e conta não suspensa.',auth: :public,output:ref('Professional'),errors:[404]); op['parameters'].find{|p|p['name']=='kind'}['schema']=s(enum:%w[guide driver])
%w[guide driver].each do |kind|
 ep('post',"/professional_profiles/#{kind}",'Perfis profissionais',"Criar/atualizar meu perfil #{kind}",'Retorna 200 inclusive no primeiro cadastro. Usa o usuário Bearer, não recebe user_id nem subscription_plan. Exige gov_verified=true. Novos perfis ou alteração de document_reference ficam pending até aprovação administrativa. Campos obrigatórios do schema descrevem a criação; em atualização podem ser omitidos se já preenchidos. Assinaturas têm endpoints próprios.',input:ref(kind=='guide' ? 'GuideInput' : 'DriverInput'),output:o('message'=>s,'profile'=>ref('PrivateProfessional')),errors:[400,403,422])
end
ep('get','/professional_profiles/mine','Perfis profissionais','Consultar meus perfis privados e desempenho',output:a(ref('PrivateProfessional')))
ep('get','/professional_profiles/commission','Perfis profissionais','Simular comissão',query:[param('amount',n(minimum:0),'Padrão zero; taxa atual da plataforma.')],output:ref('Commission'),errors:[422])
ep('get','/routes','Roteiros','Listar meus roteiros',output:a(ref('Route')))
ep('post','/routes','Roteiros','Criar meu roteiro','Recalcula itinerário, custos e alertas com preferences.destination_ids. Sem destinos limpa estimativa e itinerário.',input:ref('RouteInput'),output:ref('Route'),code:201,errors:[400,422])
ep('get','/routes/{id}','Roteiros','Consultar meu roteiro',output:ref('Route'))
%w[patch put].each{|v|ep(v,'/routes/{id}','Roteiros','Atualizar meu roteiro','Mesma ação para PUT/PATCH; recalcula estimativas conforme destinos e preferências.',input:ref('RouteInput'),output:ref('Route'),errors:[400,422])}
ep('delete','/routes/{id}','Roteiros','Excluir meu roteiro',code:204,errors:[422])
ep('post','/routes/suggest','Roteiros','Sugerir roteiro pelo catálogo','Orçamento, interesses, duração, acessibilidade e pessoas orientam a seleção. Preços e deslocamentos são estimados; não realiza reserva nem navegação viária.',input:ref('PlannerInput'),output:ref('Plan'),errors:[422])
ep('post','/routes/{id}/share','Roteiros','Habilitar compartilhamento','Reutiliza token existente; URL pública GET /shared_routes/{token}.',output:o('token'=>s))
ep('delete','/routes/{id}/share','Roteiros','Revogar compartilhamento',code:204)
ep('get','/shared_routes/{token}','Roteiros','Consultar roteiro compartilhado','Acesso público por token; não retorna identidade do dono ou credenciais.',auth: :public,output:o('title'=>s,'destination'=>s,'total_estimated_cost'=>n,'itinerary'=>a(o),'costs'=>o,'warnings'=>a(s)),errors:[404])
rec_props=S['PlannerInput']['properties'].reject{|k,_|k=='destination_ids'}.merge('message'=>s(maxLength:4000))
ep('post','/recommendations','Roteiros','Recomendar experiências por mensagem','Recomendação pelo catálogo/RoutePlanner, não LLM. Pode extrair orçamento do texto e completar região, interesses e acessibilidade do perfil.',input:o(rec_props),output:o('mode'=>s(enum:['catalog_recommendation']),'reply'=>s,'plan'=>ref('Plan')),errors:[422])
ep('get','/trails','Trilhas e saídas','Listar trilhas publicadas','Até 100, mais recentes primeiro. Trilhas publicadas de guia publicado/disponível, Gov.br verificado e não suspenso. date seleciona saídas scheduled do dia.',auth: :public,output:a(ref('Trail')),query:[param('guide_id',i),param('difficulty',s(enum:%w[easy moderate hard])),param('accessible',b),param('max_price',n),param('q',s),param('date',s(format:'date'))],errors:[422])
ep('get','/trails/{id}','Trilhas e saídas','Consultar trilha, pontos e próximas saídas',auth: :public,output:ref('Trail'))
ep('get','/trails/mine','Trilhas e saídas','Listar minhas trilhas e todas as saídas',output:a(ref('Trail')))
ep('get','/trails/{id}/edit','Trilhas e saídas','Carregar minha trilha para edição','Retorna JSON do dono incluindo saídas passadas/não públicas; não HTML.',output:ref('Trail'))
ep('post','/trails','Trilhas e saídas','Criar trilha do meu guia','Exige perfil de guia. Para publicação: guia aprovado/verificado e 2 a 50 pontos. Rascunho pode ser preenchido progressivamente. title, description, region, duration_minutes e price devem formar trilha válida. hidden não é aceito do cliente.',input:ref('TrailInput'),output:ref('Trail'),code:201,errors:[400,403,422])
%w[patch put].each{|v|ep(v,'/trails/{id}','Trilhas e saídas','Atualizar minha trilha e pontos','Pontos existentes usam id, _destroy remove e position ordena. Trilha hidden pela moderação permanece oculta mesmo após tentativa de republicação.',input:ref('TrailInput'),output:ref('Trail'),errors:[400,422])}
ep('delete','/trails/{id}','Trilhas e saídas','Arquivar minha trilha','Status archived; preserva histórico, não exclui nem retorna 204.',output:ref('Trail'),errors:[422])
ep('post','/trails/{id}/duplicate','Trilhas e saídas','Duplicar minha trilha em rascunho','Copia pontos, sem saídas ou reservas.',output:ref('Trail'),code:201,errors:[422])
ep('post','/trails/{trail_id}/departures','Trilhas e saídas','Criar saídas da minha trilha','departure obrigatório. starts_at_list na raiz permite 1 a 60 datas; sem lista usa departure.starts_at. Novas datas futuras; rejeita sobreposição do mesmo guia.',input:ref('DepartureInput'),output:a(ref('Departure')),code:201,errors:[400,422])
ep('patch','/trail_departures/{id}','Trilhas e saídas','Atualizar minha saída','Com reservas não muda horário/encontro nem reduz capacidade abaixo da ocupação. starts_at_list não é utilizado aqui.',input:ref('DepartureInput'),output:ref('Departure'),errors:[400,422])
ep('post','/trail_departures/{id}/cancel','Trilhas e saídas','Cancelar saída e reservas','Somente dono. Cancela recebimentos/reservas, marcando pagamentos aprovados como refunded. Recusa saída com serviços concluídos.',output:ref('Departure'),errors:[422])
ep('get','/trail_departures/{id}/participants','Trilhas e saídas','Consultar participantes da minha saída','Somente guia dono. Lista reservas que ocupam vagas; não é público.',output:o('departure'=>ref('Departure'),'participants'=>a(o('booking_id'=>i,'name'=>s,'people'=>i,'status'=>s,'payment_status'=>s))))
op=ep('post','/trail_departures/{departure_id}/reserve','Trilhas e saídas','Reservar vagas de trilha','Não permite reservar própria trilha. Exige aceite de requisitos, saída futura/agendada e vagas. Calcula preço por pessoa/grupo, congela itinerário/condições e segura vagas por 30 minutos. Reserva ocupante já existente retorna 200.',input:o({'people'=>i(minimum:1,maximum:100),'requirements_accepted'=>b(enum:[true]),'route_id'=>i},%w[people requirements_accepted]),output:ref('BookingResult'),code:201,errors:[404,409,422]); op['responses']['200']=response(ref('BookingResult'),'Reserva ocupante da conta já existente')
ep('get','/bookings','Reservas e pagamentos','Listar minhas reservas como cliente',output:a(ref('Booking')))
ep('post','/bookings','Reservas e pagamentos','Solicitar motorista, passeio ou parceiro','Guia deve ser reservado por saída de trilha. Motorista recebe total_amount como proposta a aceitar; valida capacidade/disponibilidade e titularidade do roteiro. Passeio/Parceiro calcula preço do destino vezes pessoas, ignorando preço do cliente.',input:ref('BookingInput'),output:ref('BookingResult'),code:201,errors:[400,422])
ep('get','/bookings/{id}','Reservas e pagamentos','Consultar reserva da minha conta','Acessível ao cliente ou prestador correspondente.',output:ref('Booking'))
ep('get','/bookings/requests','Reservas e pagamentos','Listar solicitações dos meus serviços','Escopo determinado pelos perfis/destinos do usuário autenticado.',output:a(ref('Booking')))
ep('get','/bookings/professional/{professional_id}','Reservas e pagamentos','Alias antigo da lista profissional','professional_id é ignorado pelo controller: sempre limita aos serviços do usuário autenticado. Prefira /bookings/requests.',output:a(ref('Booking')),deprecated:true)
ep('post','/bookings/{id}/counteroffer','Reservas e pagamentos','Enviar contraproposta','Só Motorista; partes alternam ofertas e não respondem à própria proposta. Registra autor, valor e histórico.',input:o({'amount'=>n(minimum:0,exclusiveMinimum:true,maximum:99999999)},['amount']),output:ref('BookingResult'),errors:[409,422])
ep('patch','/bookings/{id}/accept_offer','Reservas e pagamentos','Aceitar proposta da outra parte','Valida agenda do profissional. Não aceita a própria oferta; muda para approved_waiting_payment.',output:ref('BookingResult'),errors:[403,409,422])
ep('patch','/bookings/{id}/respond','Reservas e pagamentos','Responder proposta como profissional','accept usa a ação de accept_offer; reject restrito ao prestador encerra como rejected.',input:o({'action_type'=>s(enum:%w[accept reject])},['action_type']),output:ref('BookingResult'),errors:[403,409,422])
ep('patch','/bookings/{id}/cancel','Reservas e pagamentos','Cancelar minha reserva','Só cliente. Recusa completed/cancelled/rejected. Cancela recebimentos, marca pagamento aprovado refunded e devolve cupom sustentável respeitando validade.',output:ref('BookingResult'),errors:[409])
ep('patch','/bookings/{id}/complete','Reservas e pagamentos','Concluir serviço pago','Somente prestador de guia/motorista; cliente para Passeio/Parceiro conforme controller. Exige confirmed e approved; saída de trilha já iniciada. Libera recebimentos pending para available.',output:ref('BookingResult'),errors:[403,409,422])
ep('post','/bookings/{id}/pay','Reservas e pagamentos','Pagar minha reserva','Exige approved_waiting_payment. Simulação: cartão aprova imediatamente sem dados sensíveis; Pix aprova na quarta consulta. redemption_id reserva cupom próprio elegível e consome na aprovação; null remove. Desconto integral confirma sem cobrança. Trocar desconto reinicia Pix. Plataforma custeia desconto sem reduzir líquido do profissional. Já aprovado é idempotente.',input:ref('PayInput'),output:ref('BookingResult'),errors:[409,410,422])
ep('post','/bookings/{id}/payment_status','Reservas e pagamentos','Consultar/avançar confirmação Pix','Tem efeito de escrita: incrementa payment_polls e aprova na quarta consulta Pix. Valida hold e cupom; apenas cliente.',output:ref('BookingResult'),errors:[410,422])
ep('post','/bookings/{id}/conversation','Mensagens','Abrir conversa da reserva','Cliente ou profissional; somente Guia/Motorista com prestador.',output:o('id'=>i),errors:[422])
ep('get','/bookings/{booking_id}/discounts','Sustentabilidade','Consultar descontos elegíveis no checkout','Só reserva do cliente. Lista cupons disponíveis ou reservados nesta compra, válidos e do tipo trail/driver com desconto positivo. Ofertas novas ainda exigem conferir pontos e mínimo. Libera cupons de holds expirados da própria conta.',output:o('balance'=>i,'vouchers'=>a(o(S['EcoVoucher']['properties'].merge('discount'=>n))),'rewards'=>a(ref('EcoReward'))))
ep('get','/conversations','Mensagens','Listar minhas conversas',output:a(ref('Conversation')))
ep('post','/conversations','Mensagens','Abrir conversa antes/depois da contratação','professional_id é ID de GuideProfile/DriverProfile, não User. Exige Gov.br verificado e conta não suspensa; não conversa consigo. booking_id opcional deve ser do cliente e corresponder ao prestador. Reutiliza conversa existente, retornando 200. Tipo inválido/autoatendimento podem retornar 422 sem corpo.',input:o({'professional_type'=>s(enum:%w[Guia Motorista]),'professional_id'=>i,'booking_id'=>i},%w[professional_type professional_id]),output:ref('Conversation'),errors:[422])
ep('get','/conversations/{id}/messages','Mensagens','Listar mensagens da minha conversa','Somente participantes. Ordem criação/id, sem paginação. Mensagens ocultas têm conteúdo substituído por aviso de moderação.',output:a(ref('Message')))
ep('post','/conversations/{id}/messages','Mensagens','Enviar mensagem','Só participantes. Até 4000 caracteres; ContactPolicy bloqueia telefone, e-mail, redes sociais e links. Gera notificação e broadcast em ConversationChannel.',input:o({'content'=>s(minLength:1,maxLength:4000)},['content']),output:ref('Message'),code:201,errors:[422])
ep('post','/cable_ticket','Mensagens','Emitir ticket do WebSocket','Ticket assinado separado do Bearer, válido por um minuto. Conecte ws://localhost:3000/cable?ticket=...; canal verifica participação.',output:o('ticket'=>s))
ws=ep('get','/cable','Mensagens','Conectar ao WebSocket ActionCable','Upgrade WebSocket, não executável pelo Try it out HTTP comum. Após welcome, envie command=subscribe com identifier sendo JSON serializado de {channel: ConversationChannel, conversation_id: 1}. Recebe confirm_subscription, ping e frames {identifier, message}. Envio de conteúdo permanece pelo POST REST. Suporte usa polling, não este canal.',auth: :public,query:[param('ticket',s,'Ticket de /cable_ticket, não Bearer.','query',true)])
ws['responses']={'101'=>{'description'=>'Upgrade WebSocket'},'401'=>{'description'=>'Conexão recusada: ticket inválido ou usuário indisponível'}}
ws['x-actioncable-example']={'command'=>'subscribe','identifier'=>'{"channel":"ConversationChannel","conversation_id":1}'}
ep('get','/wallet','Carteira','Consultar saldo e movimentações','Até 200 lançamentos. Pagamento gera saldo pendente; conclusão libera ao prestador. Saques são lançamentos negativos disponíveis. Desconto sustentável preserva líquido contratado.',output:ref('Wallet'))
ep('post','/wallet/payout','Carteira','Solicitar saque simulado','Exige Gov.br verificado. amount ausente solicita saldo disponível inteiro. reference é idempotência da conta. gov_cpf dispensa chave; pix_key e bank_transfer exigem same_holder=true. Titularidade/CPF não validados com provedor real. Dados de destino ficam mascarados; simulação emite recibo completed.',input:ref('PayoutInput'),output:o('message'=>s,'entry'=>ref('WalletEntry')),errors:[403,422])
ep('post','/reviews','Avaliações e denúncias','Avaliar minha reserva concluída','Uma avaliação por reserva, somente pelo cliente e com status completed.',input:o({'booking_id'=>i,'rating'=>i(minimum:1,maximum:5),'comment'=>s(maxLength:2000)},%w[booking_id rating]),output:ref('Review'),code:201,errors:[422])
ep('post','/reports','Avaliações e denúncias','Denunciar avaliação, usuário ou mensagem','Para Message exige participação na conversa.',input:o({'subject_type'=>s(enum:%w[Review User Message]),'subject_id'=>i,'reason'=>s(minLength:1,maxLength:4000)},%w[subject_type subject_id reason]),output:ref('Report'),code:201,errors:[403,404,422])
ep('get','/notifications','Notificações','Listar minhas notificações','Últimas 100. Também gera lembretes derivados de reservas confirmadas para próximas 24h, sem agendador externo.',output:a(ref('Notification')))
%w[patch put].each{|v|ep(v,'/notifications/{id}','Notificações','Marcar notificação como lida','Não recebe campos: define read_at=Time.current. PUT/PATCH iguais.',output:ref('Notification'))}
ep('get','/subscriptions','Assinaturas','Consultar planos e minhas assinaturas','Preços no código: basic gratuito, featured R$ 29,90, premium R$ 59,90.',output:o('plans'=>o('basic'=>n(example:0),'featured'=>n(example:29.9),'premium'=>n(example:59.9)),'subscriptions'=>a(ref('Subscription')),'mock'=>b))
ep('post','/subscriptions','Assinaturas','Ativar plano gratuito','Exige perfil profissional correspondente. Somente plano de custo zero por este endpoint; pagos usam subscription_order.',input:ref('SubscriptionInput'),output:o('subscription'=>ref('Subscription'),'message'=>s),errors:[422])
%w[patch put].each{|v|ep(v,'/subscriptions/{id}','Assinaturas','Alterar renovação automática','Não altera plano/tipo profissional.',input:o('auto_renew'=>b),output:ref('Subscription'),errors:[422])}
ep('delete','/subscriptions/{id}','Assinaturas','Cancelar minha assinatura','Muda status para cancelled e auto_renew=false, sem excluir.',output:ref('Subscription'))
ep('post','/subscription_orders','Assinaturas','Criar pedido de assinatura','Exige perfil correspondente; valor calculado no servidor.',input:ref('SubscriptionInput'),output:ref('SubscriptionOrder'),code:201,errors:[422])
ep('post','/subscription_orders/{id}/pay','Assinaturas','Pagar meu pedido de assinatura','Simulado: cartão e pedido gratuito aprovam na hora; Pix espera quatro consultas. Aprovação ativa plano. Cupons de reserva não se aplicam.',input:o({'payment_method'=>s(enum:%w[pix credit_card])},['payment_method']),output:ref('SubscriptionOrder'),errors:[422])
ep('post','/subscription_orders/{id}/payment_status','Assinaturas','Consultar/avançar Pix de assinatura','Incrementa consultas do Pix pendente; a quarta aprova e ativa plano. Não é consulta somente leitura.',output:ref('SubscriptionOrder'))
ep('get','/support','Suporte','Listar meus atendimentos','Até 100 por atualização. ai=assistente, open=aguardando equipe, answered=em atendimento, closed=encerrado.',output:a(ref('SupportTicket')))
ep('post','/support','Suporte','Iniciar conversa com assistente','Persiste pergunta/resposta. IA externa usa SUPPORT_AI_URL/TOKEN e até 12 mensagens de histórico. Sem configuração oferece ajuda local. Síncrono; recomendado timeout do cliente de 35s. GET /support/{id} lê mensagens.',input:ref('SupportInput'),output:ref('SupportTicket'),code:201,errors:[409,422,429])
ep('post','/support/ask','Suporte','Alias de iniciar conversa','Mesma ação de POST /support. Agora retorna resumo do chamado, não apenas reply.',input:ref('SupportInput'),output:ref('SupportTicket'),code:201,errors:[409,422,429],deprecated:true)
ep('get','/support/{id}','Suporte','Consultar minha conversa','Sem cursor retorna últimas 100 em ordem crescente. after_id tem precedência e retorna até 100 posteriores. before_id carrega anteriores. has_older indica histórico anterior à primeira mensagem retornada. Polling a cada quatro segundos no app.',output:ref('SupportConversation'),query:[param('after_id',i),param('before_id',i)])
ep('post','/support/{id}/messages','Suporte','Enviar mensagem no suporte','Com assistente gera resposta; após transferência apenas entrega para equipe e recoloca open. Recusa encerrados ou IA já respondendo. Retorna resumo; leia mensagens por GET.',input:ref('SupportInput'),output:ref('SupportTicket'),errors:[409,429])
ep('post','/support/{id}/human','Suporte','Solicitar atendimento humano','Preserva histórico, invalida resposta IA em andamento e abre fila humana. Idempotente se já transferido; encerrados exigem nova conversa.',output:ref('SupportTicket'),errors:[409])
ep('get','/sustainability','Sustentabilidade','Consultar pontos, benefícios, cupons e extrato','Pontos ativos e benefícios válidos/com estoque/parceiro ativo. Últimos 100 cupons e 50 lançamentos próprios. Pontos não são dinheiro/saldo de saque.',query:[param('city',s(example:'Ilhéus'),'Cidade exata sem diferenciar maiúsculas: filtra pontos/parceiros, mantém benefícios internos.')],output:ref('Sustainability'))
ep('get','/sustainability/overview','Sustentabilidade','Consultar resumo da home','Saldo, quantidade de locais ativos e até três benefícios por menor custo em pontos.',output:o('balance'=>i,'collection_points_count'=>i,'rewards'=>a(ref('EcoReward'))))
ep('post','/sustainability/claim','Sustentabilidade','Creditar pontos por código de coleta','Código emitido por operador/suporte/admin. Uso único; verifica validade, cancelamento e ponto ativo. Repetição pela mesma conta não duplica pontos; outra conta é recusada. Normaliza maiúsculas e espaços nas pontas.',input:o({'collection_code'=>s(maxLength:100,example:'ECO-ILHEUS-MLH-01')},['collection_code']),output:o('balance'=>i,'message'=>s),errors:[422,429])
ep('post','/sustainability/redeem','Sustentabilidade','Trocar pontos por benefício','Débito/estoque/cupom atômicos. request_key idempotente por conta; outro benefício com mesma chave é inválido. Congela termos/endereço, validade até 30 dias ou validade do benefício. Parceiro valida código no painel; trilha/motorista usa redemption_id ao pagar.',input:o({'reward_id'=>i,'request_key'=>s(minLength:12,maxLength:100,pattern:'^[a-zA-Z0-9_-]+$',example:'resgate-ilheus-20261120-001')},%w[reward_id request_key]),output:o('voucher'=>ref('EcoVoucher'),'balance'=>i),code:201,errors:[404,422])

S['MapPoint']=o('id'=>s,'kind'=>s(enum:%w[destination trail collection partner guide driver emergency]),'name'=>s,'category'=>s(nullable:true),'address'=>s(nullable:true),'city'=>s(nullable:true),'latitude'=>n,'longitude'=>n,'approximate'=>b,'note'=>s(nullable:true),'phone'=>s(nullable:true))
ep('get','/map_points','Catálogo e destinos','Listar locais e serviços do mapa','Independente da paginação do catálogo. Destinos ativos, trilhas públicas, coleta, parceiros, profissionais publicados/verificados e apoio cadastrado. Guia/motorista representa área de atendimento, não posição em tempo real. approximate identifica resultados por rua/região. category distingue hospitais/delegacias. Endereços sem coordenadas ficam em unlocated; o cliente pode atualizar após o processamento. Não é uma busca genérica de estabelecimentos externos.',auth: :public,query:[param('q',s,'Busca por nome, endereço, cidade e categoria.'),param('kinds',s,'Tipos separados por vírgula: destination,trail,collection,partner,guide,driver,emergency.')],output:o('points'=>a(ref('MapPoint')),'total'=>i,'unlocated_count'=>i,'unlocated'=>a(o('id'=>s,'kind'=>s,'name'=>s,'address'=>s(nullable:true))),'counts'=>o),errors:[422])

S['MapPoint']['properties'].merge!('description'=>s(nullable:true),'image_url'=>s(nullable:true),'opening_hours'=>s(nullable:true),'materials'=>s(nullable:true))

# Administração JSON legada: User.admin, independente de AdminUser do painel.
legacy_fields={
 'users'=>%w[name suspended], 'guides'=>%w[moderation_status verified_documents available], 'drivers'=>%w[moderation_status verified_cnh available],
 'destinations'=>%w[name category city description image_url latitude longitude price duration_minutes opening_hours rules accessible guide_required active best_time provider_id],
 'emergency_points'=>%w[name category phone address latitude longitude], 'alerts'=>%w[title body kind region source_url expires_at],
 'reviews'=>%w[hidden], 'messages'=>%w[hidden], 'reports'=>%w[status], 'tickets'=>%w[status reply], 'subscriptions'=>%w[status], 'trails'=>%w[status]
}
resource_tables={'users'=>'users','guides'=>'guide_profiles','drivers'=>'driver_profiles','tickets'=>'support_tickets'}.merge(legacy_fields.keys.to_h{|k|[k,k]}).merge('users'=>'users','guides'=>'guide_profiles','drivers'=>'driver_profiles','tickets'=>'support_tickets')
S['LegacyRecordInput']=o(legacy_fields.flat_map{|resource,fields|fields.map{|field|[field,T.fetch(resource_tables[resource],{})[field]||s]}}.to_h)
legacy_info="Requer Bearer de User com admin=true, não cookie AdminUser. Recursos: users, guides, drivers, destinations, emergency_points, alerts, reviews, reports, tickets, subscriptions, bookings, messages, trails. Campos permitidos por recurso:\n"+legacy_fields.map{|resource,fields|"- #{resource}: #{fields.join(', ')}"}.join("\n")
ep('get','/admin/dashboard','Administração JSON legada','Consultar indicadores administrativos',legacy_info,output:o('users'=>i,'bookings'=>i,'completed'=>i,'gross'=>n,'fees'=>n,'eco_discounts'=>n,'open_reports'=>i,'open_tickets'=>i,'commission'=>n,'visits_by_destination'=>o,'bookings_by_status'=>o,'signups_by_day'=>o,'payments_mock'=>b,'analytics'=>s),errors:[403],deprecated:true)
ep('patch','/admin/commission','Administração JSON legada','Alterar taxa de comissão',legacy_info+' rate é fração entre 0 e 1, diferente do percentual do painel.',input:o({'rate'=>n(minimum:0,maximum:1)},['rate']),output:o('key'=>s,'value'=>o),errors:[403,422],deprecated:true)
ep('get','/admin/{resource}','Administração JSON legada','Listar registros administrativos',legacy_info+' Até 200, mais recentes primeiro. Usuários e reservas têm serializers próprios; demais recursos retornam campos persistidos.',output:a(o),errors:[403,404],deprecated:true)
ep('post','/admin/{resource}','Administração JSON legada','Criar atração, apoio ou comunicado',legacy_info+' Criação somente destinations/emergency_points/alerts. Retorna 200, não 201.',input:o({'record'=>ref('LegacyRecordInput')},['record']),output:o,errors:[400,403,422],deprecated:true)
ep('patch','/admin/{resource}/{id}','Administração JSON legada','Atualizar registro administrativo',legacy_info+' Não edita bookings. Publicação exige Gov.br e referência documental. Usuário não pode suspender a própria conta. Prefira o painel para suporte por chat.',input:o({'record'=>ref('LegacyRecordInput')},['record']),output:o,errors:[400,403,422],deprecated:true)
P.each{|path,methods|next unless path.start_with?('/admin/{resource}');methods.each_value{|op|op['parameters'].find{|x|x['name']=='resource'}['schema']=s(enum:%w[users guides drivers destinations emergency_points alerts reviews reports tickets subscriptions bookings messages trails])}}
redirect=ep('get','/admin','Infraestrutura','Abrir painel Rails','Redireciona para /gestao; não é endpoint JSON.',auth: :public)
redirect['responses']={'301'=>{'description'=>'Redirecionamento para /gestao','headers'=>{'Location'=>{'schema'=>s}}}}

# Equipe e formulários ActionView. Não oferecem cadastro público de AdminUser.
csrf={'authenticity_token'=>s(description:'Token do formulário da sessão; pode usar X-CSRF-Token no lugar.')}
html('get','/gestao/entrar','Exibir login da equipe','Sem login exibe formulário; conta logada é redirecionada.')['security']=[]
login=html('post','/gestao/entrar','Entrar no painel','AdminUser separado de User. Papéis: admin, suporte, operador_coleta. Sessão de até 8h com inatividade máxima de 1h. Operador vai para códigos; os demais para visão geral.',input:o(csrf.merge('email'=>s(format:'email'),'password'=>s(writeOnly:true)),%w[email password])); login['security']=[]; login['responses']['429']=response(s,'Muitas tentativas','text/html')
html('delete','/gestao/sair','Sair do painel','Audita e encerra a sessão.',input:o(csrf))
html('get','/gestao','Visão geral da equipe','Admin: indicadores e gestão integral. Suporte: atendimento/moderação sem finanças/equipe. Operador redirecionado à área de emissão de códigos.')
html('get','/gestao/relatorios','Consultar relatórios agregados','Somente admin; HTML por padrão, CSV com ?format=csv. Sem nomes, documentos ou rastreamento individual. Período máximo 365 dias.',admin:true,query:[param('from',s(format:'date')),param('to',s(format:'date')),param('format',s(enum:%w[html csv]))])['responses']['200']['content']['text/csv']={'schema'=>s}
html('get','/gestao/comissoes','Consultar comissão atual',admin:true)
html('patch','/gestao/comissoes','Alterar comissão para próximos pagamentos','percent de 0 a 100; JSON legado usa rate de 0 a 1.',admin:true,input:o(csrf.merge('percent'=>n(minimum:0,maximum:100)),['percent']))
html('post','/gestao/reservas/{id}/cancelar','Cancelar reserva e ajustar recebimentos','Recusa concluída/cancelada/rejeitada. Exige motivo com dez caracteres; cancela ganhos, simula reembolso e devolve cupom respeitando validade.',admin:true,input:o(csrf.merge('reason'=>s(minLength:10)),['reason']))

registry=Backoffice::Registry::RESOURCES
backoffice_props={}
registry.each do |resource,spec|
  table=case resource; when 'guides' then 'guide_profiles'; when 'drivers' then 'driver_profiles'; when 'tickets' then 'support_tickets'; when 'incidents' then 'system_incidents'; when 'audits' then 'admin_audits'; else resource; end
  props=spec[:edit].to_h{|field|[field,field.start_with?('password') ? s(minLength:12,maxLength:72,writeOnly:true) : T.fetch(table,{})[field]||s]}
  if props['role']; props['role']=s(enum:%w[admin suporte operador_coleta]); end
  if resource=='eco_rewards'; props['scope']=s(enum:%w[partner trail driver]); props['discount_type']=s(enum:%w[fixed percent]); end
  S["Backoffice_#{resource}"]=o(props)
  props.each{|field,type|backoffice_props["record[#{field}]"]=type}
end
S['BackofficeForm']=o(csrf.merge(backoffice_props))
permissions=<<~TEXT
  Somente admin tem gestão integral. Suporte lê #{Backoffice::Registry::SUPPORT_READ.join(', ')} e escreve #{Backoffice::Registry::SUPPORT_WRITE.join(', ')}. Operador de coleta não acessa estes recursos: só emite códigos no ponto vinculado. tickets redireciona à tela dedicada de atendimento humano; não use o formulário genérico para responder.
  Recursos e campos editáveis (campos omitidos não são alterados):
TEXT
registry.each{|resource,spec|permissions<<"- #{resource} (#{spec[:label]}): #{spec[:edit].join(', ')}. Criação: #{spec[:create] ? 'sim' : 'não'}; exclusão física: #{spec[:delete] ? 'sim, somente admin' : 'não'}.\n"}
permissions<<'Dados de usuário do app não criam AdminUser. Somente admin cria/edita equipe. Operador exige eco_collection_point_id. Alterar senha, papel, ativação ou ponto invalida sessões. Não permite desativar/rebaixar o último admin ativo. Guias/motoristas exigem Gov.br e documento para publicação.'
html('get','/gestao/registros/{resource}','Listar registros do painel',permissions,query:[param('q',s),param('status',s),param('page',i(minimum:1))])
html('get','/gestao/registros/{resource}/novo','Exibir formulário de criação',permissions,query:[param('role',s(enum:%w[admin suporte operador_coleta]),'Pré-seleção somente para admin_users.')])
html('post','/gestao/registros/{resource}','Criar registro do painel',permissions+' Use campos URL-encoded record[nome_do_campo].',input:ref('BackofficeForm'))
html('get','/gestao/registros/{resource}/{id}','Exibir detalhes do registro',permissions+' Consulta auditada, exceto leitura da própria auditoria.')
html('get','/gestao/registros/{resource}/{id}/editar','Exibir formulário de edição',permissions)
html('patch','/gestao/registros/{resource}/{id}','Salvar edição de registro',permissions+' Use campos URL-encoded record[nome_do_campo].',input:ref('BackofficeForm'))
html('delete','/gestao/registros/{resource}/{id}','Excluir registro autorizado',permissions+' Somente recursos explicitamente marcados com delete=true.',admin:true,input:o(csrf))
P.each{|path,methods|next unless path.start_with?('/gestao/registros/');methods.each_value{|op|op['parameters'].find{|x|x['name']=='resource'}['schema']=s(enum:registry.keys)}}
html('get','/gestao/pontos-de-coleta','Aba de endereços de coleta','Alias de registros/eco_collection_points. Admin cadastra e edita nome, cidade, endereço, materiais, horários, foto e coordenadas. Somente ativos aparecem no app.',admin:true,query:[param('q',s),param('page',i(minimum:1))])
html('get','/gestao/pontos-de-coleta/novo','Exibir cadastro de ponto de coleta','Formulário publica em POST /gestao/registros/eco_collection_points. Latitude e longitude devem ser informadas juntas ou ambas vazias.',admin:true)
html('get','/gestao/codigos-de-coleta','Listar códigos e formulário de entrega','Admin vê todos; suporte e operador veem os próprios. Operador só emite no ponto vinculado. Paginação de 30 por página.',query:[param('page',i(minimum:1))])
html('post','/gestao/codigos-de-coleta','Gerar código de coleta','Admin/suporte escolhem ponto ativo. Operador tem ponto forçado pelo servidor. Código único; 1..100000 pontos, expiração padrão 30 dias, máximo um ano. Emissão auditada; somente após entrega real.',input:o(csrf.merge('eco_collection_point_id'=>i,'points'=>i(minimum:1,maximum:100000),'expires_at'=>s(format:'date-time')),['points']))
html('post','/gestao/codigos-de-coleta/{id}/void','Cancelar código não utilizado','Somente admin; código já resgatado não pode ser cancelado.',admin:true,input:o(csrf))
html('get','/gestao/validar-beneficio','Consultar cupom presencial','Admin/suporte; operador de coleta não acessa. Confere cliente, benefício, estabelecimento, endereço, mínimo e validade.',query:[param('redemption_code',s)])
html('post','/gestao/validar-beneficio','Confirmar uso de benefício presencial','Admin/suporte. Apenas cupom partner disponível e não vencido. Uso único e auditado. Cupons trail/driver são consumidos no checkout do app, não aqui.',input:o(csrf.merge('redemption_code'=>s),['redemption_code']))
html('get','/gestao/atendimentos','Listar fila de suporte humano','Admin/suporte; somente chamados transferidos para humanos. Paginação de 30. Consulta de histórico antes com IA. Operador não acessa.',query:[param('status',s(enum:%w[open answered closed all],default:'open')),param('q',s,'Nome, e-mail ou assunto.'),param('page',i(minimum:1))])
html('get','/gestao/atendimentos/{id}','Abrir conversa humana','Admin/suporte. Últimas 100 mensagens; before_id carrega anteriores. Leitura auditada. Permite responder e encerrar.',query:[param('before_id',i)])
ep('get','/gestao/atendimentos/{id}/mensagens','Painel Rails (JSON de apoio)','Atualizar mensagens do atendimento','Admin/suporte com cookie, não Bearer. Até 100 mensagens após after_id; retorna partial HTML com escape ERB, last_id e status. Polling de quatro segundos sem apagar rascunho. Sem sessão pode redirecionar à página de login.',auth: :staff,query:[param('after_id',i)],output:o('html'=>s,'last_id'=>i(nullable:true),'status'=>s(enum:%w[open answered closed])),errors:[403])['responses']['302']={'description'=>'Sessão expirada: entrar no painel'}
html('post','/gestao/atendimentos/{id}/responder','Responder no chat humano','Admin/suporte. Apenas open/answered; identifica atendente, marca answered, notifica usuário e audita. Nova mensagem do usuário recoloca open.',input:o(csrf.merge('content'=>s(minLength:1,maxLength:4000)),['content']))
html('post','/gestao/atendimentos/{id}/encerrar','Encerrar atendimento humano','Admin/suporte. Apenas open/answered; mensagem de encerramento, notificação e auditoria. Histórico permanece legível.',input:o(csrf))

ui=ep('get','/api-docs','Infraestrutura','Abrir Swagger UI','Interface Rswag. Arquivos estáticos internos do engine não representam endpoints de negócio adicionais.',auth: :public); ui['responses']={'200'=>response(s,'Swagger UI','text/html'),'301'=>{'description'=>'Normalização da URL'},'302'=>{'description'=>'Redirecionamento ao Swagger UI'}}
ep('get','/api-docs/v1/swagger.yaml','Infraestrutura','Baixar este contrato OpenAPI','Arquivo estático servido pelo Rswag.',auth: :public,output:o)['responses']={'200'=>response(o,'Documento OpenAPI 3.0.1','application/yaml')}

tags=['Autenticação','Google OAuth','Conta e privacidade','Catálogo e destinos','Perfis profissionais','Roteiros','Trilhas e saídas','Reservas e pagamentos','Mensagens','Carteira','Assinaturas','Avaliações e denúncias','Notificações','Suporte','Sustentabilidade','Administração JSON legada','Painel Rails (HTML)','Painel Rails (JSON de apoio)','Infraestrutura']
document={'openapi'=>'3.0.1','info'=>{'title'=>'API Cacautrip','version'=>'v1','description'=><<~DESCRIPTION},'servers'=>[{'url'=>'http://localhost:3000','description'=>'Desenvolvimento local'}],'tags'=>tags.map{|tag|{'name'=>tag}},'security'=>[{'bearerAuth'=>[]}],'paths'=>P,'components'=>{'securitySchemes'=>{'bearerAuth'=>{'type'=>'http','scheme'=>'bearer','description'=>'Token Rails assinado retornado por signup/login/Google finish. Não é JWT. Envie Authorization: Bearer <token>. Não use credenciais AdminUser.'},'staffSession'=>{'type'=>'apiKey','in'=>'cookie','name'=>'_cacautrip_staff','description'=>'Cookie HttpOnly do painel /gestao. AdminUser é separado do usuário do app. Entre no painel no navegador da mesma origem; Swagger não define manualmente o cabeçalho Cookie. Escritas exigem CSRF.'}},'schemas'=>S}}
Documentação dos endpoints declarados em config/routes.rb e dos contratos dos controllers, incluindo aliases PUT/PATCH gerados por resources, painel ActionView e handshake ActionCable. Nenhuma chamada é executada durante a geração.

## Autenticação e permissões
API do app: Bearer obtido em signup/login/Google finish, validade de sete dias. Permissões usam a conta autenticada; IDs enviados não concedem acesso a dados alheios. Profissional novo precisa verificar Gov.br e passar por aprovação.
Painel Rails: cookie AdminUser e CSRF. admin tem gestão integral; suporte atende/modera, emite códigos e valida cupons de parceiros; operador_coleta só emite códigos do ponto vinculado e consulta seus próprios códigos. User.admin da API legada não concede automaticamente sessão AdminUser.

## Implementações de demonstração
Gov.br atualiza diretamente gov_verified=true; não há consulta real de CPF. Pix aprova na quarta consulta POST de status; cartão aprova sem gateway/dados de cartão. Saques/repasses também são simulados. Google exige configuração OAuth real. O suporte usa IA via endpoint configurado ou ajuda local na ausência dele.

## Contratos e paginação
Campos desconhecidos são ignorados conforme strong parameters. Schemas de atualização descrevem campos permitidos, não obrigam reenviar todos os atributos. Modelos continuam sujeitos às validações do banco/aplicação. Decimais persistidos podem ser strings e calculados números. Timestamps usam ISO 8601; interfaces exibem horários da Bahia. Rotas privadas exigem autenticação mesmo quando retornam 404 para registros fora do escopo.
Catálogo tem paginação opt-in. Listagens com limites fixos e mensagens com cursores têm regras descritas na operação; não existe paginação global implícita.

## Swagger e endpoints HTML
Authorize recebe apenas o token (sem prefixo Bearer). Para HTML, entre primeiro em /gestao/entrar na mesma origem e obtenha CSRF do formulário. Formulários usam application/x-www-form-urlencoded e nomes Rails como record[address]. A interface não automatiza o handshake WebSocket nem a autorização externa Google. As rotas de arquivos internos dos engines Rails/Rswag não são tratadas como APIs de negócio.
DESCRIPTION
# Exemplos são ilustrativos: IDs e disponibilidade devem ser consultados na API.
examples={
 ['post','/signup']=>{'name'=>'Ana Lima','email'=>'ana@example.com','password'=>'SenhaExemplo!2026','password_confirmation'=>'SenhaExemplo!2026'},
 ['post','/login']=>{'email'=>'ana@example.com','password'=>'SenhaExemplo!2026'},
 ['post','/professional_profiles/guide']=>{'region'=>'Ilhéus','specialization'=>'Ecoturismo e trilhas','languages'=>'Português, Inglês','description'=>'Experiências na Costa do Cacau.','image_url'=>'https://example.com/guia.jpg','document_reference'=>'REFERENCIA-DOCUMENTAL','price'=>120,'available'=>true,'accessible'=>false,'services'=>'Trilhas e passeios'},
 ['post','/professional_profiles/driver']=>{'region'=>'Ilhéus','vehicle_model'=>'Renault Duster','license_plate'=>'ABC1D23','capacity'=>4,'document_reference'=>'REFERENCIA-CNH','price'=>100,'available'=>true,'description'=>'Transporte para passeios na região.'},
 ['post','/routes']=>{'route'=>{'title'=>'Um dia em Ilhéus','destination'=>'Ilhéus','budget'=>300,'preferences'=>{'minutes'=>480,'people'=>2,'destination_ids'=>[1,2],'include_guide'=>false,'include_driver'=>true}}},
 ['post','/routes/suggest']=>{'destination'=>'Ilhéus','budget'=>300,'minutes'=>480,'people'=>2,'interests'=>'praia, gastronomia','accessible'=>false,'include_guide'=>false,'include_driver'=>true},
 ['post','/trails']=>{'trail'=>{'title'=>'Caminhos do Cacau','description'=>'Experiência guiada com duas paradas.','region'=>'Ilhéus','status'=>'draft','difficulty'=>'easy','route_mode'=>'ordered','duration_minutes'=>180,'distance_km'=>4,'price'=>120,'price_mode'=>'per_person','minimum_age'=>10,'stops_attributes'=>[{'name'=>'Encontro','address'=>'Endereço inicial em Ilhéus','position'=>1,'kind'=>'meeting','duration_minutes'=>15},{'name'=>'Ponto de visita','address'=>'Endereço final em Ilhéus','position'=>2,'kind'=>'stop','duration_minutes'=>30}]}},
 ['post','/trails/{trail_id}/departures']=>{'departure'=>{'starts_at'=>'2030-01-20T09:00:00-03:00','capacity'=>10,'meeting_point'=>'Endereço de encontro em Ilhéus','notes'=>'Chegue com quinze minutos de antecedência.'}},
 ['post','/trail_departures/{departure_id}/reserve']=>{'people'=>2,'requirements_accepted'=>true},
 ['post','/bookings']=>{'booking'=>{'service_type'=>'Motorista','service_id'=>1,'date'=>'2030-01-20 09:00','people'=>2,'meeting_point'=>'Endereço de embarque em Ilhéus','dropoff_point'=>'Endereço de destino em Ilhéus','total_amount'=>150}},
 ['post','/bookings/{id}/pay']=>{'payment_method'=>'pix','redemption_id'=>nil},
 ['post','/bookings/{id}/counteroffer']=>{'amount'=>180},
 ['post','/conversations']=>{'professional_type'=>'Motorista','professional_id'=>1},
 ['post','/conversations/{id}/messages']=>{'content'=>'Podemos combinar o embarque para as 9h?'},
 ['post','/wallet/payout']=>{'reference'=>'saque-exemplo-20261120-001','amount'=>50,'destination_type'=>'gov_cpf'},
 ['post','/support']=>{'message'=>'Preciso de ajuda com o pagamento da minha reserva.'},
 ['post','/sustainability/claim']=>{'collection_code'=>'ECO-ILHEUS-MLH-01'},
 ['post','/sustainability/redeem']=>{'reward_id'=>1,'request_key'=>'resgate-exemplo-20261120-001'},
 ['post','/auth/google/start']=>{'redirect_uri'=>'http://localhost:8081/google-callback'},
 ['post','/auth/google/finish']=>{'flow_id'=>1,'code'=>'codigo-temporario-do-retorno','exchange_secret'=>'segredo-recebido-no-inicio'}
}
examples[['post','/trails']]['trail']['stops_attributes'][1]['kind']='visit'
examples.each{|(verb,path),value|P[path][verb]['requestBody']['content']['application/json']['example']=value}
S['Destination']['properties']['distance_km']=n(nullable:true,description:'Presente quando o catálogo recebe latitude e longitude juntas.')
S['Review']['properties']['author']=s(description:'Incluído nas avaliações exibidas nos perfis e trilhas.')
%w[gross fees eco_discounts].each{|field|P['/admin/dashboard']['get']['responses']['200']['content']['application/json']['schema']['properties'][field]=ref('Decimal')}
P['/shared_routes/{token}']['get']['responses']['200']['content']['application/json']['schema']['properties']['total_estimated_cost']=ref('Decimal')
P['/health']['get']['responses']['503']=response(o('status'=>s(enum:['unavailable']),'database'=>s(enum:['unavailable'])),'Banco indisponível')
P.each do |path,methods|
  next unless path.start_with?('/gestao')
  methods.each_value do |operation|
    next unless operation.dig('responses','403','content','text/html')
    operation['responses']['403']['description']='Papel sem permissão'
    operation['responses']['422']['description']='Formulário inválido ou falha de CSRF' if operation['responses']['422']
  end
end
# JSON round-trip elimina âncoras YAML compartilhadas entre schemas reutilizados.
File.write(File.join(ROOT,'swagger/v1/swagger.yaml'),YAML.dump(JSON.parse(JSON.generate(document))))
count=P.values.sum(&:length)
File.write(File.join(ROOT,'swagger/v1/ENDPOINTS.md'),"# Endpoints Cacautrip\n\nContrato: swagger.yaml. Abrir em http://localhost:3000/api-docs.\n\n#{P.size} caminhos e #{count} operações HTTP documentados.\n\n| Método | Caminho | Grupo | Operação |\n|---|---|---|---|\n"+P.flat_map{|path,methods|methods.map{|verb,op|"| #{verb.upcase} | `#{path}` | #{op['tags'].first} | #{op['summary']} |"}}.join("\n")+"\n\nGerador: script/build_openapi.rb. Lê o schema versionado e as permissões estáticas; não inicia o Rails nem consulta o banco. Não substitui testes da API.\n")
puts "OpenAPI atualizado: #{P.size} caminhos, #{count} operações, #{S.size} schemas."
