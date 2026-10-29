# Endpoints Cacautrip

Contrato: swagger.yaml. Abrir em http://localhost:3000/api-docs.

100 caminhos e 126 operações HTTP documentados.

| Método | Caminho | Grupo | Operação |
|---|---|---|---|
| POST | `/signup` | Autenticação | Cadastrar turista |
| POST | `/login` | Autenticação | Entrar com e-mail e senha |
| GET | `/me` | Conta e privacidade | Consultar minha conta e papéis |
| PATCH | `/me` | Conta e privacidade | Atualizar dados, preferências ou papel ativo |
| POST | `/me/verify_gov` | Conta e privacidade | Verificar Gov.br no fluxo de demonstração |
| GET | `/privacy/export` | Conta e privacidade | Exportar meus dados pessoais |
| POST | `/privacy/deletion_request` | Conta e privacidade | Solicitar exclusão/anonimização |
| POST | `/auth/google/start` | Google OAuth | Iniciar cadastro/login ou vinculação Google |
| GET | `/auth/google/callback` | Google OAuth | Receber retorno do Google |
| POST | `/auth/google/finish` | Google OAuth | Trocar código temporário por sessão |
| GET | `/health` | Infraestrutura | Consultar Rails e PostgreSQL |
| GET | `/catalog` | Catálogo e destinos | Consultar destinos, alertas e apoio |
| GET | `/destinations/{id}` | Catálogo e destinos | Consultar destino ativo |
| GET | `/professional_profiles/guides` | Perfis profissionais | Listar guias públicos |
| GET | `/professional_profiles/drivers` | Perfis profissionais | Listar motoristas públicos |
| GET | `/professional_profiles/{kind}/{id}` | Perfis profissionais | Consultar perfil público |
| POST | `/professional_profiles/guide` | Perfis profissionais | Criar/atualizar meu perfil guide |
| POST | `/professional_profiles/driver` | Perfis profissionais | Criar/atualizar meu perfil driver |
| GET | `/professional_profiles/mine` | Perfis profissionais | Consultar meus perfis privados e desempenho |
| GET | `/professional_profiles/commission` | Perfis profissionais | Simular comissão |
| GET | `/routes` | Roteiros | Listar meus roteiros |
| POST | `/routes` | Roteiros | Criar meu roteiro |
| GET | `/routes/{id}` | Roteiros | Consultar meu roteiro |
| PATCH | `/routes/{id}` | Roteiros | Atualizar meu roteiro |
| PUT | `/routes/{id}` | Roteiros | Atualizar meu roteiro |
| DELETE | `/routes/{id}` | Roteiros | Excluir meu roteiro |
| POST | `/routes/suggest` | Roteiros | Sugerir roteiro pelo catálogo |
| POST | `/routes/{id}/share` | Roteiros | Habilitar compartilhamento |
| DELETE | `/routes/{id}/share` | Roteiros | Revogar compartilhamento |
| GET | `/shared_routes/{token}` | Roteiros | Consultar roteiro compartilhado |
| POST | `/recommendations` | Roteiros | Recomendar experiências por mensagem |
| GET | `/trails` | Trilhas e saídas | Listar trilhas publicadas |
| POST | `/trails` | Trilhas e saídas | Criar trilha do meu guia |
| GET | `/trails/{id}` | Trilhas e saídas | Consultar trilha, pontos e próximas saídas |
| PATCH | `/trails/{id}` | Trilhas e saídas | Atualizar minha trilha e pontos |
| PUT | `/trails/{id}` | Trilhas e saídas | Atualizar minha trilha e pontos |
| DELETE | `/trails/{id}` | Trilhas e saídas | Arquivar minha trilha |
| GET | `/trails/mine` | Trilhas e saídas | Listar minhas trilhas e todas as saídas |
| GET | `/trails/{id}/edit` | Trilhas e saídas | Carregar minha trilha para edição |
| POST | `/trails/{id}/duplicate` | Trilhas e saídas | Duplicar minha trilha em rascunho |
| POST | `/trails/{trail_id}/departures` | Trilhas e saídas | Criar saídas da minha trilha |
| PATCH | `/trail_departures/{id}` | Trilhas e saídas | Atualizar minha saída |
| POST | `/trail_departures/{id}/cancel` | Trilhas e saídas | Cancelar saída e reservas |
| GET | `/trail_departures/{id}/participants` | Trilhas e saídas | Consultar participantes da minha saída |
| POST | `/trail_departures/{departure_id}/reserve` | Trilhas e saídas | Reservar vagas de trilha |
| GET | `/bookings` | Reservas e pagamentos | Listar minhas reservas como cliente |
| POST | `/bookings` | Reservas e pagamentos | Solicitar motorista, passeio ou parceiro |
| GET | `/bookings/{id}` | Reservas e pagamentos | Consultar reserva da minha conta |
| GET | `/bookings/requests` | Reservas e pagamentos | Listar solicitações dos meus serviços |
| GET | `/bookings/professional/{professional_id}` | Reservas e pagamentos | Alias antigo da lista profissional |
| POST | `/bookings/{id}/counteroffer` | Reservas e pagamentos | Enviar contraproposta |
| PATCH | `/bookings/{id}/accept_offer` | Reservas e pagamentos | Aceitar proposta da outra parte |
| PATCH | `/bookings/{id}/respond` | Reservas e pagamentos | Responder proposta como profissional |
| PATCH | `/bookings/{id}/cancel` | Reservas e pagamentos | Cancelar minha reserva |
| PATCH | `/bookings/{id}/complete` | Reservas e pagamentos | Concluir serviço pago |
| POST | `/bookings/{id}/pay` | Reservas e pagamentos | Pagar minha reserva |
| POST | `/bookings/{id}/payment_status` | Reservas e pagamentos | Consultar/avançar confirmação Pix |
| POST | `/bookings/{id}/conversation` | Mensagens | Abrir conversa da reserva |
| GET | `/bookings/{booking_id}/discounts` | Sustentabilidade | Consultar descontos elegíveis no checkout |
| GET | `/conversations` | Mensagens | Listar minhas conversas |
| POST | `/conversations` | Mensagens | Abrir conversa antes/depois da contratação |
| GET | `/conversations/{id}/messages` | Mensagens | Listar mensagens da minha conversa |
| POST | `/conversations/{id}/messages` | Mensagens | Enviar mensagem |
| POST | `/cable_ticket` | Mensagens | Emitir ticket do WebSocket |
| GET | `/cable` | Mensagens | Conectar ao WebSocket ActionCable |
| GET | `/wallet` | Carteira | Consultar saldo e movimentações |
| POST | `/wallet/payout` | Carteira | Solicitar saque simulado |
| POST | `/reviews` | Avaliações e denúncias | Avaliar minha reserva concluída |
| POST | `/reports` | Avaliações e denúncias | Denunciar avaliação, usuário ou mensagem |
| GET | `/notifications` | Notificações | Listar minhas notificações |
| PATCH | `/notifications/{id}` | Notificações | Marcar notificação como lida |
| PUT | `/notifications/{id}` | Notificações | Marcar notificação como lida |
| GET | `/subscriptions` | Assinaturas | Consultar planos e minhas assinaturas |
| POST | `/subscriptions` | Assinaturas | Ativar plano gratuito |
| PATCH | `/subscriptions/{id}` | Assinaturas | Alterar renovação automática |
| PUT | `/subscriptions/{id}` | Assinaturas | Alterar renovação automática |
| DELETE | `/subscriptions/{id}` | Assinaturas | Cancelar minha assinatura |
| POST | `/subscription_orders` | Assinaturas | Criar pedido de assinatura |
| POST | `/subscription_orders/{id}/pay` | Assinaturas | Pagar meu pedido de assinatura |
| POST | `/subscription_orders/{id}/payment_status` | Assinaturas | Consultar/avançar Pix de assinatura |
| GET | `/support` | Suporte | Listar meus atendimentos |
| POST | `/support` | Suporte | Iniciar conversa com assistente |
| POST | `/support/ask` | Suporte | Alias de iniciar conversa |
| GET | `/support/{id}` | Suporte | Consultar minha conversa |
| POST | `/support/{id}/messages` | Suporte | Enviar mensagem no suporte |
| POST | `/support/{id}/human` | Suporte | Solicitar atendimento humano |
| GET | `/sustainability` | Sustentabilidade | Consultar pontos, benefícios, cupons e extrato |
| GET | `/sustainability/overview` | Sustentabilidade | Consultar resumo da home |
| POST | `/sustainability/claim` | Sustentabilidade | Creditar pontos por código de coleta |
| POST | `/sustainability/redeem` | Sustentabilidade | Trocar pontos por benefício |
| GET | `/map_points` | Catálogo e destinos | Listar locais e serviços do mapa |
| GET | `/admin/dashboard` | Administração JSON legada | Consultar indicadores administrativos |
| PATCH | `/admin/commission` | Administração JSON legada | Alterar taxa de comissão |
| GET | `/admin/{resource}` | Administração JSON legada | Listar registros administrativos |
| POST | `/admin/{resource}` | Administração JSON legada | Criar atração, apoio ou comunicado |
| PATCH | `/admin/{resource}/{id}` | Administração JSON legada | Atualizar registro administrativo |
| GET | `/admin` | Infraestrutura | Abrir painel Rails |
| GET | `/gestao/entrar` | Painel Rails (HTML) | Exibir login da equipe |
| POST | `/gestao/entrar` | Painel Rails (HTML) | Entrar no painel |
| DELETE | `/gestao/sair` | Painel Rails (HTML) | Sair do painel |
| GET | `/gestao` | Painel Rails (HTML) | Visão geral da equipe |
| GET | `/gestao/relatorios` | Painel Rails (HTML) | Consultar relatórios agregados |
| GET | `/gestao/comissoes` | Painel Rails (HTML) | Consultar comissão atual |
| PATCH | `/gestao/comissoes` | Painel Rails (HTML) | Alterar comissão para próximos pagamentos |
| POST | `/gestao/reservas/{id}/cancelar` | Painel Rails (HTML) | Cancelar reserva e ajustar recebimentos |
| GET | `/gestao/registros/{resource}` | Painel Rails (HTML) | Listar registros do painel |
| POST | `/gestao/registros/{resource}` | Painel Rails (HTML) | Criar registro do painel |
| GET | `/gestao/registros/{resource}/novo` | Painel Rails (HTML) | Exibir formulário de criação |
| GET | `/gestao/registros/{resource}/{id}` | Painel Rails (HTML) | Exibir detalhes do registro |
| PATCH | `/gestao/registros/{resource}/{id}` | Painel Rails (HTML) | Salvar edição de registro |
| DELETE | `/gestao/registros/{resource}/{id}` | Painel Rails (HTML) | Excluir registro autorizado |
| GET | `/gestao/registros/{resource}/{id}/editar` | Painel Rails (HTML) | Exibir formulário de edição |
| GET | `/gestao/pontos-de-coleta` | Painel Rails (HTML) | Aba de endereços de coleta |
| GET | `/gestao/pontos-de-coleta/novo` | Painel Rails (HTML) | Exibir cadastro de ponto de coleta |
| GET | `/gestao/codigos-de-coleta` | Painel Rails (HTML) | Listar códigos e formulário de entrega |
| POST | `/gestao/codigos-de-coleta` | Painel Rails (HTML) | Gerar código de coleta |
| POST | `/gestao/codigos-de-coleta/{id}/void` | Painel Rails (HTML) | Cancelar código não utilizado |
| GET | `/gestao/validar-beneficio` | Painel Rails (HTML) | Consultar cupom presencial |
| POST | `/gestao/validar-beneficio` | Painel Rails (HTML) | Confirmar uso de benefício presencial |
| GET | `/gestao/atendimentos` | Painel Rails (HTML) | Listar fila de suporte humano |
| GET | `/gestao/atendimentos/{id}` | Painel Rails (HTML) | Abrir conversa humana |
| GET | `/gestao/atendimentos/{id}/mensagens` | Painel Rails (JSON de apoio) | Atualizar mensagens do atendimento |
| POST | `/gestao/atendimentos/{id}/responder` | Painel Rails (HTML) | Responder no chat humano |
| POST | `/gestao/atendimentos/{id}/encerrar` | Painel Rails (HTML) | Encerrar atendimento humano |
| GET | `/api-docs` | Infraestrutura | Abrir Swagger UI |
| GET | `/api-docs/v1/swagger.yaml` | Infraestrutura | Baixar este contrato OpenAPI |

Gerador: script/build_openapi.rb. Lê o schema versionado e as permissões estáticas; não inicia o Rails nem consulta o banco. Não substitui testes da API.
