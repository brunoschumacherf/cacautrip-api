# App web local usando a API do Render

Se a API já está publicada, configure no ambiente do serviço Rails no Render:

```env
CORS_ORIGINS=http://localhost:8081,http://127.0.0.1:8081
CABLE_ORIGINS=http://localhost:8081,http://127.0.0.1:8081
```

Preserve outros domínios do frontend que já utiliza: acrescente as origens locais à lista existente, separando por vírgulas. Informe somente protocolo, hostname e porta; não coloque /login ou outro caminho. Essas variáveis pertencem ao servidor Rails, não ao Expo. Um arquivo .env no computador não altera o ambiente do Render.

Salve as variáveis e reinicie/reimplante o serviço para que os initializers sejam carregados novamente. A variável EXPO_PUBLIC_API_URL do app deve continuar apontando para https://cacautrip-api.onrender.com se a intenção for usar essa API.

O initializer mantém Rack::Cors no início da pilha e permite OPTIONS, Content-Type, Authorization e os métodos usados pela API. Sem CORS_ORIGINS configurado, produção permite apenas as duas origens locais do Expo acima; uma lista explícita substitui esse padrão. Em desenvolvimento, sem lista explícita, o comportamento aberto anterior é preservado. Não são habilitados cookies entre origens: a API usa token Bearer e o painel HTML tem sessão própria.

O Action Cable usa CABLE_ORIGINS quando definido, depois CORS_ORIGINS e, por último, as mesmas duas origens locais em produção. Para o frontend publicado, adicione sua origem HTTPS às duas listas.

Esta alteração não exige migration. Se o erro persistir depois de configurar o ambiente e publicar o código, confira os logs do Render: uma resposta da plataforma por falha de inicialização/indisponibilidade também pode chegar sem cabeçalhos CORS.

Não foram executados testes nem alteradas configurações remotas nesta solicitação.

Referência: https://github.com/cyu/rack-cors#configuration
