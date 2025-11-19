# Insomnia Collection - Expense Split API

Coleção do Insomnia para testar a Expense Split API localmente.

## 🚀 Como Usar

### 1. Iniciar a API Localmente

```bash
# Iniciar com Docker Compose
docker compose up -d

# Verificar se está rodando
curl http://localhost:8080/health
```

### 2. Importar a Coleção no Insomnia

1. Abra o Insomnia
2. Clique em **Application** → **Preferences** → **Data**
3. Configure o **Git Repository** para apontar para este repositório
4. O Insomnia detectará automaticamente o arquivo `ExpenseSplitAPI.yaml` nesta pasta

**Ou importe manualmente:**
- **Import/Export** → **Import Data** → **From File**
- Selecione: `.insomnia/ExpenseSplitAPI.yaml`

### 3. Configurar Variáveis de Ambiente

A coleção já está configurada para uso local. Verifique se a variável está correta:

- **baseURL**: `http://localhost:8080/api/v1`

Para verificar/editar:
1. No Insomnia, clique no dropdown de ambiente (canto superior direito)
2. Selecione **Manage Environments**
3. Verifique que `baseURL` está configurado como `http://localhost:8080/api/v1`

## 📁 Estrutura da Coleção

A coleção está organizada em 5 pastas principais:

### 👤 User
- **POST Sign Up** - Criar novo usuário
- **POST Sign In** - Autenticar e obter JWT token (token é salvo automaticamente)
- **GET Me** - Obter perfil do usuário autenticado
- **GET List Users** - Listar todos os usuários

### 🎯 Activities
- **POST Create Activity** - Criar nova atividade
- **GET List Activities** - Listar atividades do usuário
- **GET Activity Detail** - Detalhes de uma atividade
- **PUT Update Activity** - Atualizar atividade
- **DELETE Activity** - Deletar atividade

### 💰 Expenses
- **POST Create Expense** - Criar despesa
- **GET List Expenses** - Listar despesas de uma atividade
- **GET Expense Detail** - Detalhes de uma despesa
- **PUT Update Expense** - Atualizar despesa
- **PUT Set Payer** - Definir/atualizar pagador
- **POST Mark Payment** - Registrar pagamento
- **DELETE Expense** - Deletar despesa

### 👥 Activity Participants
- **POST Add Participants** - Adicionar participantes à atividade
- **GET List Participants** - Listar participantes
- **DELETE Remove Participant** - Remover participante

### ⚖️ Balance
- **GET Activity Balance** - Saldo de uma atividade
- **GET Balance Between Users** - Saldo entre dois usuários
- **GET User Global Balance** - Saldo global do usuário
- **GET Detailed Balance** - Saldo detalhado do usuário

## 🔐 Autenticação

A coleção está configurada para:

1. **Fazer login** com **Sign In** (usa `alice@example.com` / `12121212` por padrão)
2. **Extrair automaticamente** o token JWT da resposta
3. **Usar o token** em todas as requests protegidas via Bearer Authentication

O token é salvo automaticamente na variável `token` e usado em todas as requests que requerem autenticação.

## 🧪 Dados de Teste (Seed)

Se você rodou o seed do banco de dados, pode usar estes usuários:

| Email | Senha | Nome |
|-------|-------|------|
| `alice@example.com` | `12121212` | Alice Johnson |
| `bob@example.com` | `12121212` | Bob Smith |
| `charlie@example.com` | `12121212` | Charlie Brown |
| `diana@example.com` | `12121212` | Diana Prince |

## 📝 Fluxo de Teste Recomendado

1. **Autenticar**: Use **Sign In** com `alice@example.com` / `12121212`
2. **Criar Atividade**: Use **Create Activity**
3. **Adicionar Participantes**: Use **Add Participants** (adicionar Bob, Charlie, etc.)
4. **Criar Despesas**: Use **Create Expense** para a atividade
5. **Ver Saldo**: Use **Activity Balance** para ver quem deve a quem
6. **Registrar Pagamentos**: Use **Mark Payment** quando alguém pagar

## 🌍 Localização

A API está configurada para usar **pt-BR** como locale padrão no ambiente de desenvolvimento.

Para testar em inglês, adicione o header:
```
Accept-Language: en
```

Ou use o query parameter:
```
?lang=en
```

## 🔄 Sincronização com Git

A coleção está versionada no Git. Quando você fizer mudanças:

1. O Insomnia salvará automaticamente (se auto-save estiver ativo)
2. Faça commit das mudanças:
   ```bash
   git add .insomnia/
   git commit -m "docs: update Insomnia collection"
   git push
   ```

## ⚠️ Troubleshooting

### API não responde
- Verifique se o Docker está rodando: `docker compose ps`
- Verifique os logs: `docker compose logs app`
- Teste o health endpoint: `curl http://localhost:8080/health`

### Token não está sendo salvo
- Verifique se o request **Sign In** está retornando o token no campo `token`
- Verifique a configuração de autenticação no request **Me** (deve usar Bearer token)

### Erro 401 Unauthorized
- Faça login novamente com **Sign In**
- Verifique se o token está sendo enviado no header `Authorization: Bearer <token>`

## 📚 Documentação Adicional

- **Swagger UI**: http://localhost:8080/docs
- **OpenAPI JSON**: http://localhost:8080/openapi.json
