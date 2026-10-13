# RUSMEDIA server (Dart)

```
cp .env.example .env          # already present for dev
docker compose up -d          # from the repo root: Postgres + MinIO
dart pub get
dart run bin/migrate.dart     # creates the tables
dart test                     # unit tests
dart run bin/server.dart      # http://localhost:8080/api/health
```
