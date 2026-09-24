# Deploy Android (Google Play)

Pipeline: `.github/workflows/android.yml`.

- Pull request: `flutter analyze` + `flutter test`.
- Tag `v*` (ex.: `git tag v0.1.0 && git push --tags`) ou "Run workflow" manual: testa, gera o `.aab` assinado e envia para a trilha `internal` (ou a escolhida no manual).
- `versionCode` = número de build do `pubspec.yaml` (`version: x.y.z+N`), incrementado por `make mobile-release`; `versionName` = `x.y.z`.

## Setup único

1. **Keystore de upload** (guarde o `.jks` fora do repo, ex.: `C:/Users/ramon/keys/erp/`, e as senhas num cofre; nunca commitar):
   ```bash
   keytool -genkeypair -v -storetype JKS -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. **Play Console**: criar o app com package `com.ramonmachadocarmo.erp`, ativar Play App Signing e subir o **primeiro** `.aab` manualmente (a API não cria o app). Para o primeiro build, gere localmente com `android/key.properties` apontando para o keystore:
   ```
   storeFile=C:/Users/ramon/keys/erp/upload-keystore.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```
   e rode `flutter build appbundle --release --dart-define=API_BASE_URL=https://erp.personalia.cloud`.
3. **Service account**: Google Cloud → habilitar "Google Play Android Developer API" → criar service account e uma chave JSON. No Play Console → Usuários e permissões → convidar o e-mail da service account com permissão de release nesse app.
4. **GitHub** → Settings → Environments → criar `play-store` (opcional: exigir aprovação manual) e cadastrar:
   - Secrets: `ANDROID_KEYSTORE_BASE64` (`base64 -w0 upload-keystore.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `PLAY_SERVICE_ACCOUNT_JSON` (conteúdo do JSON).
   - Variable: `API_BASE_URL` = `https://erp.personalia.cloud` (as rotas do app já incluem `/api/...`).

Contas pessoais criadas após nov/2023 precisam de teste fechado com 12 testadores por 14 dias antes de liberar produção.

## Publicar uma versão

Duas etapas, na raiz do monorepo (`erp/`). Só a segunda dispara o CI/CD.

```bash
# 1) prepara: calcula a versão, atualiza o pubspec (build number +1), commita só ele e cria a tag — LOCAL
make mobile-release patch          # 0.2.1 -> 0.2.2   (ou: minor | major | VERSION=0.3.0)

# 2) publica: push do branch + da tag vX.Y.Z = DISPARA o pipeline (testes -> .aab -> Google Play internal)
make mobile-publish                # pede para digitar o nome da tag; TAG=vX.Y.Z para uma específica
```

Ambos aceitam `ARGS=-n` (dry-run, não altera nada) e `ARGS=-y` (sem perguntar).

- Ao contrário do `ship.sh` (que builda o que está em disco), o CI faz checkout do GitHub: **só entra o que estiver commitado e com push**. O `mobile-release` avisa quando há arquivos sem commit e recusa se o `pubspec.yaml` estiver alterado (ele commita só esse arquivo).
- Trava anti-downgrade: a versão nova precisa ser maior que qualquer tag existente (local ou remota).
- `mobile-publish` recusa tag que já exista no remote (não redispararia nada) e empurra **só** a tag indicada, nunca `--tags`.
- Desfazer a etapa 1, antes de publicar: `cd mobile && git tag -d vX.Y.Z && git reset -q HEAD~1 && git checkout -- pubspec.yaml` (o comando também é impresso pelo script).
- Depois de publicado não há rollback pela tag: pause a distribuição no Play Console ou publique uma versão maior (`make mobile-release patch && make mobile-publish`).
