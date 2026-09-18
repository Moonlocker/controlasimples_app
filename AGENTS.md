# AGENTS.md — Controla Simples (app Flutter)

Aplicativo mobile do Controla Simples. Consome o mesmo backend Supabase do
projeto web (`../controlasimples`) e a API REST `/api/mobile/*` desse web.

## Stack

- Flutter (Dart SDK `^3.13.3`) + Material 3
- `supabase_flutter` (Auth, Postgres via RLS)
- `flutter_riverpod` (estado) + `go_router` (navegação)
- `fl_chart`, `pdf`/`printing`, `share_plus`, `image_picker`, `url_launcher`, `intl`

## Comandos

```sh
flutter pub get
dart format lib test            # formatação canônica
flutter analyze                 # lints/erros (deve ficar em "No issues found!")
flutter test                    # testes unitários/widget
flutter run                     # executa em um dispositivo/emulador
flutter build apk --debug       # valida a compilação Android
```

Variáveis de build (`--dart-define`, ver `lib/core/config/app_config.dart`):
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `API_BASE_URL` (padrão
`https://controlasimples.com.br`).

## Estrutura

```
lib/
  core/            # config, router, tema, enums, utils (datas/derive/período)
  features/        # telas por domínio (auth, onboarding, dashboard, clients,
                   # charges, services, quotes, reports, settings, admin, ...)
  models/          # DTOs e mapas das tabelas (fromMap/toMap)
  repositories/    # acesso a dados (Supabase + API mobile) e providers Riverpod
  services/        # clientes HTTP/Supabase
  widgets/         # componentes reutilizáveis
```

Regra de camadas: telas → `repositories`/`providers` → Supabase ou API. Telas
não fazem chamadas HTTP/Supabase diretas (exceto backup em Configurações).

## Integração com o backend

- **Supabase direto (RLS)**: clientes, serviços (`projects`), cobranças,
  pagamentos, recorrências, orçamentos, `user_business`, perfis, planos.
- **API REST `/api/mobile/*`**: assinatura de plano, Asaas (config/emitir/
  arquivos/sync/auto) e WhatsApp (uso/enviar/validar). Sempre com
  `Authorization: Bearer <access_token>`.
- **Admin `/api/mobile/admin/*`**: restrito a superadmin (Asaas/WhatsApp da
  plataforma, cotas, templates e exclusão de usuários).
- **Notificações `/api/mobile/notifications/*`**: preferências automáticas de
  WhatsApp (com os limites do superadmin) e histórico por cliente.

Observações importantes:
- A tabela `projects` é exibida como "Serviços" na UI; no banco continua
  `projects` e a FK `project_id`.
- Escrita direta em `subscriptions` e em colunas sensíveis de `profiles` é
  bloqueada por gatilhos; use o endpoint de assinatura.
- `charge_status` no banco não tem `atrasado`; o status é derivado no app
  (`core/utils/derive.dart`).
- `profiles.setup_completed` controla o assistente de primeiros passos
  (`features/onboarding`).

## Convenções

- Dinheiro em `double` (BRL); datas em `yyyy-MM-dd` via `core/utils/dates.dart`.
- Novos recursos: criar `model` + `repository`/provider + tela em `features/`.
- Sempre rodar `dart format`, `flutter analyze` e `flutter test` antes de finalizar.
- Não commitar segredos; a anon key pública fica em `app_config.dart`.

## Projeto relacionado

`../controlasimples` — backend/web (TanStack Start + Supabase). As migrações
SQL ficam em `../controlasimples/supabase/migrations`.
