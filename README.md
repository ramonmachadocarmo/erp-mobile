# Mobile

Flutter (Android / iOS). Clean Architecture + Feature-first. HTTP pelo gateway em `:3100`.

```
lib/
  app/           MaterialApp, go_router, tema, shell
  core/          config, Dio+JWT, session, maps, json
  features/      auth, config, stock, sales, purchasing, logistics, …
```

Cada feature: `domain` / `data` / `presentation`. JWT em `flutter_secure_storage`.

| Ambiente | Base URL |
|---|---|
| Android emulator | `http://10.0.2.2:3100` |
| iOS simulator | `http://localhost:3100` |
| Device | `--dart-define=API_BASE_URL=http://<LAN>:3100` |

Login: `admin@erp.local` / `admin123`

Usuários: Configurador → Usuários (`/config/usuarios`).

## Logística

Rotas (`/logistica/rotas`): CD, veículos, entregas `PICKED`/`UNDELIVERED`, montar N rotas, opções (tempo / distância / alternativa), confirmar, Maps (rota completa) e Waze (parada). Relatório por plano.

Entrega (`/logistica/entrega`): confirmar, falha (motivo obrigatório → `UNDELIVERED`) ou cancelar (`DELIVERED` → `PICKED`).

## Testes

```bash
cd apps/mobile && flutter test
make test-mobile
```
