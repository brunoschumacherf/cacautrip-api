# Painel administrativo Rails / Action View

## Acesso

URL: `/gestao`. `/admin` redireciona para a mesma área. As rotas JSON existentes em `/admin/dashboard` e `/admin/:resource` continuam disponíveis para o app.

O painel usa controllers `Backoffice::* < ActionController::Base`, templates ERB e CSS em `public/backoffice.css`. Não depende de React, Turbo ou JavaScript para operar os formulários. A API continua herdando de `ActionController::API`.

## Equipe

`AdminUser` é separado de `User`. Possui senha BCrypt, papel `admin` ou `suporte`, ativação e versão de sessão. A senha exige ao menos 12 caracteres; alterações de credenciais, papel ou ativação invalidam sessões anteriores.

- **admin:** acesso às operações, aprovação e documentação de profissionais, catálogo, trilhas, alertas, emergência, moderação, suporte, reservas, pagamentos, carteiras, assinaturas, comissão, relatórios, auditoria e gestão da equipe.
- **suporte:** consulta de usuários, reservas, alertas e emergência; tratamento de chamados, denúncias, avaliações, mensagens e incidentes. Não aprova profissionais, não altera dados cadastrais ou financeiros e não administra membros da equipe.

Permissões são aplicadas no servidor em todas as ações. A interface não é a única barreira de acesso.

## Segurança e privacidade

Sessões usam cookie HttpOnly, SameSite=Lax, restrito a `/gestao`, Secure em produção, prazo absoluto de oito horas e expiração após uma hora sem atividade. Login regenera a sessão; logout a remove. Formulários possuem proteção CSRF e os endpoints com alteração usam POST/PATCH/DELETE. Páginas autenticadas não devem ser armazenadas em cache.

Não existe cadastro público de AdminUser. Somente administradores criam novas contas da equipe. O último administrador ativo não pode ser desativado ou rebaixado pelo formulário.

Mutações e leitura de registros individuais geram `AdminAudit`. Não são gravadas senhas, parâmetros completos ou cópias de documentos no histórico de alterações. Informações documentais são restritas à administração.

`SystemIncident` registra classe da falha, ponto técnico, request_id e trechos locais da pilha. Não armazena mensagem da exceção, IP, query string, corpo de requisição ou parâmetros pessoais. Falhas tratadas por validação não viram incidentes genéricos.

Relatórios e CSV apresentam apenas contagens e totais agregados. A análise de fluxo usa roteiros por destino e vagas contratadas por região, sem inferir presença física ou rastrear deslocamentos individuais. Exportações são auditadas e o CSV neutraliza células que possam ser interpretadas como fórmulas.

## Operação

- Aprovação de guias/motoristas exige Gov.br autenticado e referência documental preenchida.
- Suporte responde chamados e o usuário recebe uma notificação no app.
- Denúncias levam ao registro correspondente para moderação. Avaliações e mensagens são ocultadas, preservando o histórico.
- Reservas antes da conclusão podem ser canceladas pela administração com motivo obrigatório, cancelando o crédito do prestador e marcando o pagamento para estorno. Serviços concluídos exigem revisão, evitando reverter saldos já sacados automaticamente.
- Comissão alterada vale para novos pagamentos; os valores históricos ficam preservados.
- Assinaturas podem ter situação e renovação controladas; pagamentos e repasses são consultados por seus registros.
- Trilhas continuam sendo criadas e mantidas pelos guias; a equipe administrativa pode moderar a publicação.

Pagamentos, Gov.br e repasses mantêm o comportamento de demonstração do MVP. Este painel não conecta um provedor financeiro real.

## Provisionamento local

```bash
docker compose run --rm -v /home/afoxavier/cacautrip:/workspace -e NOTES_PATH=/workspace/notes.md web bash -c 'bundle exec rails db:migrate && bundle exec rails runner script/seed_admin_users.rb'
docker compose restart web
```

O script atualiza exclusivamente duas contas locais da equipe e substitui apenas a seção de acessos do backoffice em `notes.md`. Não limpa o banco nem altera contas de turistas/guias/motoristas.

## Limites de operação

A captura técnica começa após a aplicação conseguir inicializar e gravar no banco. Falhas de boot, banco indisponível e infraestrutura devem também ser monitoradas pelos logs/healthcheck externos. A limitação de tentativas de login é local por processo; use limitação distribuída no gateway em produção. Políticas de retenção, atendimento de direitos do titular e procedimentos de backup continuam sendo definições de operação.
