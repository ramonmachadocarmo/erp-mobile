# Deploy Android (Google Play)

Pipeline: `.github/workflows/android.yml`.

- Pull request: `flutter analyze` + `flutter test`.
- Tag `v*` (ex.: `git tag v0.1.0 && git push --tags`) ou "Run workflow" manual: testa, gera o `.aab` assinado e envia para a trilha `internal` (ou a escolhida no manual).
- `versionCode` = número da run do GitHub; `versionName` = campo `version` do `pubspec.yaml`.

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
