# Cacautrip — API Rails

Código preparado para o fluxo: cadastro → Gov.br mock → perfil profissional → aprovação administrativa → proposta → aceite → pagamento mock → serviço → carteira → repasse mock.

## Preparação manual

```bash
docker compose up -d db
docker compose build web
docker compose run --rm web bundle exec rails db:prepare
docker compose run --rm -e ADMIN_EMAIL=seu-email -e ADMIN_PASSWORD=sua-senha web bundle exec rails db:seed
docker compose up -d web
```

As migrations novas **não foram executadas** nesta alteração. O seed cria sugestões de demonstração; horários e preços devem ser mantidos pela administração. Não há senha administrativa padrão. Não use dados reais de cartão ou documentos em um ambiente de demonstração.

## Comportamento

- `/signup`, `/login`: conta única. Demais endpoints privados usam `Authorization: Bearer <token>`.
- `/me`: dados, preferências e perfil ativo. `/me/verify_gov`: autenticação instantânea mock.
- `/professional_profiles/guides` e `/drivers`: anúncios aprovados, filtros e reputação. Alterar referência documental retorna o cadastro para análise.
- `/catalog`: destinos, alertas e pontos de apoio cadastrados. Distância é aproximada; preços do seed são demonstrativos.
- `/routes`: roteiros do usuário. Várias reservas podem apontar para o mesmo roteiro.
- `/bookings`: reservas próprias. `/bookings/requests`: solicitações recebidas. `respond`, `cancel` e `complete` controlam as transições.
- `POST /bookings/:id/pay`: aceita `pix` ou `credit_card`. Cartão sempre aprova, sem receber dados do cartão. Pix aprova após quatro chamadas a `POST /bookings/:id/payment_status`.
- A confirmação grava a comissão e cria um único crédito pendente na carteira do prestador dentro da transação. Concluir libera o crédito. Cancelar antes da conclusão registra estorno mock e cancela o crédito.
- `/wallet`: saldo, pendências, taxas, extrato e pagamentos. `/wallet/payout`: registra débito do saldo disponível como repasse mock.
- `/reviews`: uma avaliação por reserva concluída. `/reports`: denúncias de avaliação, usuário ou mensagem.
- `/conversations`: conversas persistidas; podem estar vinculadas à reserva. Somente participantes acessam mensagens.
- `/notifications`: mensagens, alterações e lembretes de reservas. Alertas de clima e segurança são comunicados cadastrados pela administração, não previsão meteorológica automática.
- `/subscriptions`: planos demonstrativos de um mês, sem cobrança real nem renovação automática.
- `/admin/dashboard` e `/admin/:resource`: administração autorizada pelo campo `admin`, sem permitir autopromoção pelo cadastro público.
- Relatórios mostram contagens agregadas por destino, sem armazenar histórico de coordenadas individuais.

## IA e suporte

`POST /support/ask` integra um gateway de IA definido por `SUPPORT_AI_URL` (HTTPS) e `SUPPORT_AI_TOKEN`. O gateway recebe `{ "message": "...", "context": "..." }` e responde `{ "reply": "..." }`. Sem configuração, a interface identifica as respostas como ajuda local por regras. `/support` registra chamados humanos, respondidos no painel administrativo.

As variáveis do `.env.example` precisam ser fornecidas ao processo/container pelo ambiente. A IA externa não recebe dados de conta ou carteira automaticamente.

## Refatoração das jornadas

O desempenho agora é serializado explicitamente em professional_profiles#mine. Novos endpoints incluem GET /bookings/:id, POST /bookings/:id/conversation, POST /routes/suggest, POST /routes/:id/share, DELETE /routes/:id/share, GET /shared_routes/:token e POST /recommendations.

O Compose prepara o banco antes de iniciar a API e inclui um processo de manutenção das renovações simuladas. O campo auto_renew exige autorização do usuário; a alteração do mesmo plano vigente não gera outra cobrança.

GET /privacy/export permite consultar dados da própria conta; POST /privacy/deletion_request abre solicitação humana. GET /health oferece status de disponibilidade sem expor dados privados.

Backup e restauração manual ficam em script/backup.sh e script/restore.sh. Nenhuma dessas rotinas foi executada nesta alteração. Consulte também o REFACTOR.md no aplicativo.


## Trilhas criadas pelos guias

As ofertas de trilhas ficam em Trail, com pontos em TrailStop e saídas em TrailDeparture. O guia gerencia suas próprias ofertas em /trails/mine e /trails/:id/edit. Os turistas consultam /trails e /trails/:id e reservam em POST /trail_departures/:id/reserve. O preço e a capacidade são controlados pelo servidor; a reserva guarda um snapshot do percurso contratado. Detalhes em TRAILS.md na raiz do workspace.

