# RUSMEDIA (Flutter + Dart)

- `server/`  Dart backend: Shelf, PostgreSQL (`postgres`), S3-compatible storage with SigV4 presigned URLs
- `app/`     Flutter client (Android, iOS, web): public gallery + admin
- `docker-compose.yml`  Postgres + MinIO for development

Status: Phase 2 foundation. See server/README.md and app/README.md to run it.
Architecture is unchanged from the Phase 1 document (direct-to-storage multipart uploads, private originals,
CDN-served thumbnails, background worker, roles ADMIN / SUPER_ADMIN); only the language and framework changed.
