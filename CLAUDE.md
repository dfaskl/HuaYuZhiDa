# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

化语智答（HuaYuZhiDa）是面向高校师生的智能问答系统，基于私有知识库与 RAG 架构构建，融合向量检索与大语言模型，实现对教务通知、课程信息等非结构化数据的语义检索与精准问答，支持多轮对话与实时流式响应。

Spring Boot 3.4.2 后端 + Vue 3 + TypeScript 前端。所有后端配置通过根目录 `.env` 文件驱动，由 `DotenvEnvironmentPostProcessor` 在最高优先级加载，YAML 文件中使用 `${ENV_VAR:default}` 占位符。

## Development Commands

### Prerequisites
Java 17, Maven 3.8.6+, Node.js 18.20.0+, pnpm 8.7.0+, MySQL 8.0, Elasticsearch 8.10.0, MinIO 8.5.12, Kafka 3.2.1, Redis 7.0.11.

### Setup
```bash
cp .env.example .env  # Edit with real credentials before running anything
```

### Backend
```bash
mvn spring-boot:run                                    # Start with dev profile (default)
mvn spring-boot:run -Dspring-boot.run.profiles=docker  # Start with docker profile
mvn clean package                                      # Build JAR
mvn test                                               # Run all tests (uses H2 in-memory DB)
mvn test -Dtest=UserServiceTest                        # Run single test class
mvn test -Dtest=UserServiceTest#testMethod             # Run single test method
```

Tests use H2 in-memory database and point to local Ollama (`localhost:11434`) for LLM, `localhost:8000` for embeddings. ES initialization is disabled in test profile.

### Frontend
```bash
cd frontend
pnpm install          # Install dependencies
pnpm dev              # Dev server on port 9527, proxies API to backend :8081
pnpm dev:prod         # Dev server with prod backend
pnpm build            # Production build
pnpm build:test       # Test environment build
pnpm typecheck        # Type checking (vue-tsc)
pnpm lint             # ESLint with auto-fix
```

### Infrastructure (local services)
```bash
./infra.sh start      # Start MinIO, Kafka, Elasticsearch
./infra.sh stop       # Stop all
./infra.sh status     # Check status
./infra.sh logs       # Tail logs
```
Note: `infra.sh` has hardcoded macOS paths in the service directory variables — adjust for your environment.

### Deployment
```bash
./deploy-front.sh                        # Build frontend + SCP to server
cp launch.sh.example launch.sh           # Edit for backend server deployment
```

## Architecture

### RAG Pipeline (core data flow)
```
Upload (chunked to MinIO) → Kafka topic → FileProcessingConsumer
  → ParseService (Tika for general docs, LiteParse CLI for PDFs with page-level OCR)
  → HanLP semantic chunking (paragraph → sentence → overlap, 512 tokens / 100 overlap)
  → MySQL (document_vectors table)
  → VectorizationService → EmbeddingClient (DashScope text-embedding-v4, 2048 dimensions)
  → Elasticsearch (huayu_knowledge_base index, IK Chinese analyzer, cosine similarity)
```

### Chat / Query Flow
```
WebSocket /chat/{token} → ChatWebSocketHandler → ChatHandler
  → RateLimitService.check
  → HybridSearchService.searchWithPermission (KNN 30x recall + BM25 rescore, dept-tag filtered)
  → LlmProviderRouter.streamReActTurn (ReAct agent loop: max 4 rounds, 8 tool calls)
  → AgentToolRegistry tools: search_knowledge, generate_summary, submit_feedback, knowledge_stats
  → Stream chunks to WebSocket client
  → Persist conversation to MySQL + Redis
```

### Multi-tenancy (院系隔离)
- Users and resources carry `deptTags` (comma-separated on User entity, single tag on resources)
- `DeptTagAuthorizationFilter` (after JWT filter in the security chain) enforces three-tier access: private (owner only), department (dept members), public (all)
- `DeptTagCacheService` resolves parent-child department tag hierarchies
- `HybridSearchService` filters ES queries by department tags

### Authentication & Security
- JWT tokens (1h access, 7d refresh) with Redis-backed caching and blacklisting
- `JwtAuthenticationFilter` validates tokens and auto-refreshes proactively (5 min before expiry) or within grace period (10 min after expiry), returns new token via `New-Token` response header
- `DeptTagAuthorizationFilter` runs after JWT filter for resource-level authorization
- Admin endpoints (`/api/v1/admin/**`) require ADMIN role; document/chat endpoints require USER or ADMIN

### Token Usage Quota (dual-mode)
- **Daily mode** (`UsageQuotaService`): Redis sliding window, resets daily (300K LLM / 1M embedding tokens default)
- **Balance mode** (`UsageBalanceQuotaService`): Purchased token balance, persists across days
- Selected by `useUserTokenBalance` flag in `UsageQuotaProperties`
- Streaming LLM calls use reservation/settlement pattern to track actual usage

### Backend Package Layout (`com.huayu.smartqa`)
- `config/` — Infrastructure beans (Redis, ES, Kafka, MinIO, WebClient), security chain (SecurityConfig, JwtAuthenticationFilter, DeptTagAuthorizationFilter), initializers (admin bootstrap, dept tags, ES index, knowledge bootstrap), property binding classes
- `controller/` — 12 REST controllers under `/api/v1/`
- `service/` — 30 service classes; `ChatHandler` orchestrates the ReAct loop, `LlmProviderRouter` routes to configurable LLM providers stored in DB
- `consumer/` — `FileProcessingConsumer` handles upload processing and reindex tasks from Kafka
- `handler/` — `ChatWebSocketHandler` manages WebSocket connections with JWT auth in URL path
- `client/` — `DeepSeekClient` (OpenAI-compatible streaming), `EmbeddingClient` (batch with retry)
- `model/` — JPA entities (User, FileUpload, DocumentVector, DepartmentTag, Conversation, etc.)
- `entity/` — ES documents (EsDocument) and DTOs (SearchResult, TextChunk, Message)
- `repository/` — 16 Spring Data JPA repositories + RedisRepository
- `utils/` — JwtUtils (Redis-backed token management), LogUtils (MDC structured logging), PasswordUtil (BCrypt)

### Frontend Architecture
- **pnpm monorepo** with workspace packages under `frontend/packages/`: `@sa/axios` (HTTP client with flat request pattern), `@sa/hooks`, `@sa/utils`, `@sa/materials`, `@sa/color`, `@sa/scripts`, `@sa/uno-preset`
- **Auto-imports**: `unplugin-auto-import` imports Vue, Pinia, Vue Router, dayjs, Naive UI types, plus all exports from `service/api/`, `store/modules/`, `hooks/`, `enum/`, `utils/`, `constants/` — many function calls appear without explicit imports
- **Routing**: `@elegant-router/vue` auto-generates route definitions from filesystem conventions; supports static (compiled) and dynamic (API-fetched) auth route modes
- **State**: Pinia stores use Composition API (setup) syntax with a custom `resetSetupStore` plugin enabling `$reset()`. Key stores: `auth-store` (tokens, user info, role), `route-store` (dynamic menus, route filtering), `chat-store` (WebSocket, conversations, streaming), `knowledge-base-store` (chunked upload with MD5 dedup, 5MB chunks, 4 concurrent per file)
- **API layer**: `createFlatRequest` from `@sa/axios` returns `{ data, error }` tuples. Backend response shape: `{ code: string, message: string, data: T }`. Token refresh uses singleton promise pattern to deduplicate concurrent refresh attempts.
- **WebSocket chat**: URL `/proxy-ws/chat/{token}`, heartbeat every 20s, auto-reconnect with 1500ms delay. On reconnect, fetches generation snapshot via REST to sync state.
- **Dev server**: port 9527, proxies to backend 8081. Router history mode is `hash`.
- **Theming**: Comprehensive system with light/dark/auto, 4 layout modes, CSS variable injection, Naive UI overrides, grayscale/colour-weakness accessibility modes.
- **i18n**: vue-i18n with zh-CN and en-US, Composition API mode, strongly typed.

### Environment Configuration
- Root `.env` file drives all backend config via `DotenvEnvironmentPostProcessor`
- Frontend `.env.test` (dev, points to localhost:8081) and `.env.prod` (relative paths)
- Backend profiles: `dev` (default, ES http), `docker` (MinIO port 19000), `prod` (no show-sql, restricted logging)
- Test profile: H2 in-memory DB (`jdbc:h2:mem:paismart;MODE=MySQL`), `ddl-auto: create-drop`

### Key Infrastructure Dependencies
| Service | Purpose | Default Port |
|---|---|---|
| MySQL 8.0 | Primary database (JPA/Hibernate, `ddl-auto: update`) | 3306 |
| Elasticsearch 8.10 | Vector + full-text hybrid search, IK Chinese analyzer | 9200 |
| Redis 7.0 | Rate limiting, token caching/blacklisting, conversation history | 6379 |
| Kafka 3.2 | Async file processing (`huayu-file-processing`, dead-letter: `huayu-file-processing-dlt`) | 9092 |
| MinIO 8.5 | Object storage for uploaded files (`huayu-uploads` bucket) | 9000 |

### Git Hooks
`simple-git-hooks` runs on pre-commit: `cd frontend && pnpm typecheck && pnpm lint && git diff --exit-code`. Commit messages are verified by `pnpm sa git-commit-verify`.

### No In-Repo Docker/CI
No `docker-compose.yml`, `Dockerfile`, or CI pipeline files exist in the repository. Docker and CI are managed externally. Deployment uses `deploy-front.sh` (SCP) and `launch.sh.example` (server-side script).
