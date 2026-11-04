# Calendário - Aula 7 (Programação para Dispositivos Móveis)

Aplicativo Flutter que consulta o calendário do dispositivo e lista os
compromissos de hoje e dos próximos 6 dias (7 dias no total), usando o pacote
`device_calendar`.

## Como rodar

Este repositório contém apenas o código do app (`lib/` e `pubspec.yaml`).
A pasta `android/` é gerada pelo Flutter:

```
git clone <url-do-repositorio>
cd calendario
flutter create . --platforms=android
flutter pub get
```

Se o Flutter criar o arquivo `test/widget_test.dart`, apague-o (ele referencia
um app de exemplo que não existe aqui).

### Permissões no Android

Abra `android/app/src/main/AndroidManifest.xml` e adicione, dentro de
`<manifest>` e antes de `<application>`:

```xml
<uses-permission android:name="android.permission.READ_CALENDAR" />
<uses-permission android:name="android.permission.WRITE_CALENDAR" />
```

### Executar

Use um emulador Android ou um celular (o pacote não funciona na web):

```
flutter run
```

## Se der erro no build

Adicione em `android/gradle.properties`:

```
kotlin.compiler.execution.strategy=in-process
kotlin.incremental=false
```
