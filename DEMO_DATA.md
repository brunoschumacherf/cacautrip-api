# Recriar os dados de apresentação

No Ubuntu/WSL, na raiz `cacautrip`:

```bash
bash cacautrip-api/script/rebuild_demo_data.sh --reset --build
```

O script reconstrói a imagem Rails, aguarda o PostgreSQL, para API e manutenção, salva o banco e o notes.md em uma pasta privada dentro de `cacautrip-api/storage/backups/`, limpa somente o schema de `cacautrip_development`, aplica todas as migrations com `db:prepare` e executa a carga completa. Depois reinicia os serviços usando o mesmo banco local. Não executa testes nem build do Expo.

**O comando apaga todos os dados locais**, incluindo cadastros manuais. Não é um comando para produção. `--reset` é obrigatório para evitar execução acidental. O script pode ser chamado de qualquer diretório; não depende do caminho do usuário original. Se ocorrer falha, ele para e informa a pasta de backup; a carga não é retomada automaticamente.

Dados gerados:

- 10 turistas sem Gov.br verificado, 10 motoristas e 10 guias publicados e verificados, mais a conta administrativa do aplicativo;
- duas trilhas por guia, pontos de passagem, datas futuras, histórico, reservas pagas, avaliações, conversas e saldos em carteira;
- contas AdminUser para admin e suporte, três operadores de coleta e planos de destaque em seis profissionais;
- pontos de coleta e parceiros de apresentação em Ilhéus, benefícios, códigos, pontos e cupons resgatados;
- destinos, hospitais, delegacias, UPA da Esperança e Pronto Atendimento da Zona Sul.

As senhas e os códigos atuais serão escritos no **notes.md da raiz**. As senhas das contas do painel são geradas novamente a cada recriação. As datas são calculadas a partir do dia da execução. Gov.br, Pix, cartão e saques continuam com os fluxos de apresentação existentes.

A geocodificação consulta o provedor configurado no projeto e pode demorar. Para gerar os dados sem essas consultas:

```bash
bash cacautrip-api/script/rebuild_demo_data.sh --reset --build --no-geocode
```

Nesse caso, os pontos que já têm coordenadas aparecem no mapa; os demais mantêm o endereço e precisam ser localizados posteriormente com `script/backfill_map_coordinates.rb`. Durante a carga, jobs assíncronos e notificações são suprimidos para evitar tarefas concorrentes.

Se a imagem já estiver atualizada, remova `--build`. Backups do PostgreSQL estão no formato custom (`pg_dump -Fc`) e o notes.md anterior fica na mesma pasta. A restauração deve ser feita manualmente para o banco local, usando `pg_restore`; não exclua o backup antes de conferir os dados manualmente.

A carga foi preparada em código, sem executar containers, migrations ou seeds nesta solicitação.

## Banco de apresentação no Render

Existe um fluxo separado para a base remota `cacautrip`, no host externo autorizado em `lib/demo_seed_database.rb`:

```bash
bash cacautrip-api/script/rebuild_remote_demo_data.sh --reset
```

A URL é configurada no `.env` ignorado pelo Git (`CACAUTRIP_DATABASE_URL`). O arquivo privado `.env.remote-seed` contém PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD, PGSSLMODE e PGCONNECT_TIMEOUT para o backup e precisa apontar para a mesma base. Não publique esses arquivos. O comando salva primeiro um dump PostgreSQL custom e uma cópia do notes.md em `storage/backups/render-demo-*`; somente depois limpa o schema, aplica migrations e gera a base completa. As credenciais da aplicação ficam no notes.md da raiz.

A autorização remota exige `ALLOW_REMOTE_DEMO_RESET=cacautrip`, o nome do banco, o host exato e `RESET_DATABASE=cacautrip`, definidos pelo script. O fluxo local mantém suas proteções anteriores. A aplicação hospedada pode ficar indisponível enquanto o schema e os dados são recriados. Em caso de falha, o backup permanece preservado; o script não tenta restaurar automaticamente nem reinicia o serviço no Render.
