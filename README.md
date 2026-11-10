# Diagnóstico de Rede — App Android

App de diagnóstico de rede em Flutter, com **build automático de APK** pelo GitHub Actions.

## Como pegar o APK
1. Vá na aba **Actions** deste repositório.
2. Abra a execução mais recente de **"Build APK"** (espere ficar verde, ~10 min).
3. Em **Artifacts**, baixe **diagnostico-rede-apk**.
4. Descompacte, copie o `app-release.apk` pro celular e instale.

A cada atualização do código, um novo APK é gerado automaticamente.

## Estrutura
- `app_src/main.dart` — código do app (telas: Status, Canais Wi-Fi, Velocidade, Senha).
- `.github/workflows/build-apk.yml` — receita que cria o projeto Flutter, aplica permissões e builda o APK.
