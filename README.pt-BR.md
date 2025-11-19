<div align="center">

[English](./README.md) | **Português (BR)**

</div>

---

# Expense Split API

Uma API RESTful para dividir despesas entre amigos, construída com Swift e Vapor 4.

## ✨ Funcionalidades

- 🔐 **Autenticação JWT** - Autenticação segura baseada em tokens
- 💰 **Rastreamento de Despesas** - Criar e gerenciar despesas com divisão igual
- 🔄 **Compensação Global de Dívidas** - Cálculo automático de saldo entre todas as atividades
- 👥 **Suporte Multi-usuário** - Múltiplos usuários por atividade
- 🌍 **Internacionalização** - Suporte para Inglês e Português (pt-BR)
- 📚 **OpenAPI/Swagger** - Documentação interativa da API
- 🐳 **Suporte Docker** - Desenvolvimento local fácil
- ☁️ **Pronto para Render.com** - Configuração de deploy no tier gratuito

## 🚀 Início Rápido

### Pré-requisitos

- Docker & Docker Compose
- PostgreSQL 16 (incluído no Docker Compose)

### Desenvolvimento Local

```bash
# Clonar repositório
git clone <url-do-repositorio>
cd ExpenseSplitAPI

# Iniciar com Docker Compose
docker compose up -d

# API estará disponível em http://localhost:8080
# Documentação Swagger em http://localhost:8080/docs

# Ver logs
docker compose logs -f app

# Parar serviços
docker compose down
```

### Primeira Requisição

```bash
# Verificar saúde da API
curl http://localhost:8080/health

# Criar conta
curl -X POST http://localhost:8080/api/v1/users/sign-up \
  -H "Content-Type: application/json" \
  -d '{
    "name": "João Silva",
    "email": "joao@exemplo.com",
    "password": "senha123"
  }'
```

## 📚 Documentação

- **Documentação Interativa**: http://localhost:8080/docs (Swagger UI)
- **Especificação OpenAPI**: http://localhost:8080/openapi.json
- **Coleção Insomnia**: [`.insomnia/ExpenseSplitAPI.yaml`](./.insomnia/ExpenseSplitAPI.yaml)

## 🏗️ Estrutura do Projeto

```
ExpenseSplitAPI/
├── Sources/ExpenseSplitAPI/
│   ├── Controllers/          # Manipuladores de requisições
│   │   ├── AuthController.swift
│   │   ├── ActivityController.swift
│   │   ├── ExpenseController.swift
│   │   ├── ParticipantController.swift
│   │   └── BalanceController.swift
│   ├── Models/               # Modelos de dados & DTOs
│   │   ├── User.swift
│   │   ├── Activity.swift
│   │   ├── Expense.swift
│   │   └── DTOs/
│   ├── Services/             # Lógica de negócio
│   │   ├── BalanceService.swift
│   │   ├── CompensationService.swift
│   │   └── LocalizedText.swift
│   ├── Middleware/           # Middleware customizado
│   │   ├── UserAuthenticator.swift
│   │   └── LocalizationMiddleware.swift
│   ├── Migrations/           # Migrações do banco de dados
│   └── Resources/             # Arquivos de localização
│       └── Localizable.xcstrings
├── .insomnia/                # Coleção do Insomnia
├── Public/swagger/           # Arquivos do Swagger UI
├── docker-compose.yml        # Desenvolvimento local
├── render.yaml               # Deploy no Render.com
└── Dockerfile                # Imagem Docker
```

## 🔌 Endpoints da API

### Autenticação
- `POST /api/v1/users/sign-up` - Registrar novo usuário
- `POST /api/v1/users/sign-in` - Autenticar e obter token JWT
- `GET /api/v1/users/me` - Obter perfil do usuário atual (Protegido)

### Atividades
- `POST /api/v1/activities` - Criar atividade
- `GET /api/v1/users/:userId/activities` - Listar atividades do usuário
- `GET /api/v1/activities/:activityId` - Obter detalhes da atividade
- `PUT /api/v1/activities/:activityId` - Atualizar atividade
- `DELETE /api/v1/activities/:activityId` - Deletar atividade

### Despesas
- `POST /api/v1/activities/:activityId/expenses` - Criar despesa
- `GET /api/v1/activities/:activityId/expenses` - Listar despesas
- `GET /api/v1/expenses/:expenseId` - Obter detalhes da despesa
- `PUT /api/v1/expenses/:expenseId` - Atualizar despesa
- `PUT /api/v1/expenses/:expenseId/payer` - Definir/atualizar pagador
- `POST /api/v1/expenses/:expenseId/payments` - Registrar pagamento
- `DELETE /api/v1/expenses/:expenseId` - Deletar despesa

### Participantes
- `POST /api/v1/activities/:activityId/participants` - Adicionar participantes
- `GET /api/v1/activities/:activityId/participants` - Listar participantes
- `DELETE /api/v1/activities/:activityId/participants/:userId` - Remover participante

### Saldo
- `GET /api/v1/activities/:activityId/balance` - Saldo da atividade
- `GET /api/v1/balance/between/:userId1/:userId2` - Saldo entre usuários
- `GET /api/v1/balance/users/:userId/global` - Saldo global do usuário
- `GET /api/v1/balance/users/:userId/detailed` - Saldo detalhado

## 🌍 Internacionalização

A API suporta múltiplos idiomas via header `Accept-Language` ou parâmetro `lang`:

```bash
# Português (padrão no ambiente de teste)
curl -H "Accept-Language: pt-BR" http://localhost:8080/api/v1/users/sign-in

# Inglês
curl -H "Accept-Language: en" http://localhost:8080/api/v1/users/sign-in

# Ou usar parâmetro de query
curl "http://localhost:8080/api/v1/users/sign-in?lang=en"
```

Idiomas suportados:
- 🇺🇸 Inglês (en)
- 🇧🇷 Português (pt-BR)

## 🧪 Testes

### Usando Insomnia

1. Importe a coleção de `.insomnia/ExpenseSplitAPI.yaml`
2. Configure a variável de ambiente `baseURL` para `http://localhost:8080/api/v1`
3. Comece com a requisição **Sign In** (usa dados do seed: `alice@example.com` / `12121212`)
4. O token é salvo automaticamente e usado em requisições protegidas

### Dados de Seed

Quando `SEED_DATABASE=true`, os seguintes usuários de teste são criados:

| Email | Senha | Nome |
|-------|-------|------|
| `alice@example.com` | `12121212` | Alice Johnson |
| `bob@example.com` | `12121212` | Bob Smith |
| `charlie@example.com` | `12121212` | Charlie Brown |
| `diana@example.com` | `12121212` | Diana Prince |

## ⚙️ Variáveis de Ambiente

### Obrigatórias

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `DATABASE_HOST` | Host do PostgreSQL | `localhost` |
| `DATABASE_PORT` | Porta do PostgreSQL | `5432` |
| `DATABASE_NAME` | Nome do banco de dados | `expense_split_dev` |
| `DATABASE_USERNAME` | Usuário do banco | `vapor` |
| `DATABASE_PASSWORD` | Senha do banco | `password` |
| `JWT_SECRET` | Chave secreta JWT (mín 32 caracteres) | - |

### Opcionais

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `ENVIRONMENT` | Nome do ambiente | `development` |
| `SERVER_PORT` | Porta do servidor | `8080` |
| `DEFAULT_LOCALE` | Idioma padrão | `en` (prod), `pt-BR` (test) |
| `SEED_DATABASE` | Habilitar seed do banco | `false` |

## 🐳 Comandos Docker

```bash
# Iniciar serviços
docker compose up -d

# Ver logs
docker compose logs -f app

# Parar serviços
docker compose down

# Resetar banco de dados (remove todos os dados)
docker compose down -v
docker compose up -d

# Reconstruir após mudanças no código
docker compose build app
docker compose up -d
```

## ☁️ Deploy

### Render.com (Tier Gratuito)

1. Faça push do código para o GitHub
2. Acesse [Render.com](https://render.com) e crie um novo Blueprint
3. Conecte seu repositório
4. O Render detectará automaticamente o `render.yaml` e fará deploy de ambos os ambientes

**Ambientes:**
- **Produção**: `https://expense-split-api-prod.onrender.com`
- **Teste/Estudantes**: `https://expense-split-api-test.onrender.com`

Veja [render.yaml](./render.yaml) para configuração.

## 🔒 Segurança

- ✅ Autenticação baseada em token JWT
- ✅ Hash de senhas com Bcrypt
- ✅ Validação de entrada em todos os endpoints
- ✅ Mensagens de erro localizadas
- ✅ Suporte a CORS
- ✅ Proteção contra SQL injection (via Fluent ORM)

## 📊 Esquema do Banco de Dados

```
users
├── activities (many-to-many via activity_participants)
├── expenses (como pagador)
└── expense_participants (como devedor)

activities
├── participants (many-to-many via activity_participants)
└── expenses

expenses
├── payer (opcional, pode ser definido depois)
├── participants (many-to-many via expense_participants)
└── payments (via expense_payments)
```

## 🛠️ Desenvolvimento

### Executando Localmente (sem Docker)

```bash
# Instalar Swift 6.1+
# Instalar PostgreSQL

# Criar banco de dados
createdb expense_split_dev

# Definir variáveis de ambiente
export DATABASE_HOST=localhost
export DATABASE_PORT=5432
export DATABASE_NAME=expense_split_dev
export DATABASE_USERNAME=seu_usuario
export DATABASE_PASSWORD=sua_senha
export JWT_SECRET=sua-chave-secreta-min-32-chars
export ENVIRONMENT=development

# Compilar e executar
swift build
swift run
```

### Executando Testes

```bash
swift test
```

## 📝 Licença

MIT License - veja o arquivo [LICENSE](./LICENSE) para detalhes

## 🤝 Contribuindo

1. Faça um fork do repositório
2. Crie sua branch de feature (`git checkout -b feature/minha-feature`)
3. Faça commit das mudanças (`git commit -m 'Adiciona minha feature'`)
4. Faça push para a branch (`git push origin feature/minha-feature`)
5. Abra um Pull Request

## 📞 Suporte

- 📖 **Documentação da API**: http://localhost:8080/docs
- 🐛 **Problemas**: Crie uma issue no GitHub
- 💬 **Dúvidas**: Consulte a documentação ou abra uma discussão

## 🙏 Agradecimentos

- Construído com [Vapor](https://vapor.codes) - Framework Swift para servidor
- Banco de dados: [PostgreSQL](https://www.postgresql.org)
- Documentação da API: [Swagger UI](https://swagger.io/tools/swagger-ui/)
- Deploy: [Render.com](https://render.com)

---

<div align="center">

**Feito com ❤️ usando Swift & Vapor**

[English](./README.md) | [Português (BR)](./README.pt-BR.md)

</div>

