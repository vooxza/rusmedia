CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TYPE role_t          AS ENUM ('ADMIN', 'SUPER_ADMIN');
CREATE TYPE visibility_t    AS ENUM ('PUBLIC', 'UNLISTED', 'PRIVATE');
CREATE TYPE album_status_t  AS ENUM ('ACTIVE', 'ARCHIVED');
CREATE TYPE file_type_t     AS ENUM ('IMAGE', 'VIDEO');
CREATE TYPE file_status_t   AS ENUM ('UPLOADING', 'PROCESSING', 'READY', 'FAILED');
CREATE TYPE upload_status_t AS ENUM ('INITIATED', 'UPLOADING', 'COMPLETED', 'ABORTED', 'FAILED');

CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         text NOT NULL UNIQUE,
  name          text NOT NULL,
  password_hash text NOT NULL,
  role          role_t NOT NULL DEFAULT 'ADMIN',
  is_active     boolean NOT NULL DEFAULT true,
  last_login_at timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- Opaque, revocable session tokens. Only the SHA-256 hash of the token is stored.
CREATE TABLE sessions (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  token_hash text NOT NULL UNIQUE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL,
  user_agent text,
  ip         text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sessions_user_idx    ON sessions(user_id);
CREATE INDEX sessions_expires_idx ON sessions(expires_at);

CREATE TABLE categories (
  id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  slug text NOT NULL UNIQUE
);

CREATE TABLE albums (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title            text NOT NULL,
  slug             text NOT NULL UNIQUE,
  description      text,
  event_date       date NOT NULL,
  year             int  NOT NULL,
  category_id      uuid REFERENCES categories(id),
  cover_file_id    uuid UNIQUE,
  visibility       visibility_t   NOT NULL DEFAULT 'PUBLIC',
  download_enabled boolean        NOT NULL DEFAULT true,
  status           album_status_t NOT NULL DEFAULT 'ACTIVE',
  archived_at      timestamptz,
  photo_count      int    NOT NULL DEFAULT 0,
  video_count      int    NOT NULL DEFAULT 0,
  total_bytes      bigint NOT NULL DEFAULT 0,
  created_by_id    uuid NOT NULL REFERENCES users(id),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  deleted_at       timestamptz
);
CREATE INDEX albums_year_idx     ON albums(year, event_date DESC);
CREATE INDEX albums_listing_idx  ON albums(status, visibility, deleted_at, event_date DESC);
CREATE INDEX albums_category_idx ON albums(category_id);
CREATE INDEX albums_title_trgm   ON albums USING gin (title gin_trgm_ops);

CREATE TABLE folders (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  album_id   uuid NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
  name       text NOT NULL,
  sort_order int  NOT NULL DEFAULT 0
);
CREATE INDEX folders_album_idx ON folders(album_id, sort_order);

CREATE TABLE files (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  album_id       uuid NOT NULL REFERENCES albums(id),
  folder_id      uuid REFERENCES folders(id),
  uploaded_by_id uuid NOT NULL REFERENCES users(id),
  file_name      text NOT NULL,
  storage_key    text NOT NULL UNIQUE,
  mime_type      text NOT NULL,
  file_type      file_type_t NOT NULL,
  file_size      bigint NOT NULL,
  width          int,
  height         int,
  duration       double precision,
  thumb_key      text,
  preview_key    text,
  poster_key     text,
  blur_hash      text,
  taken_at       timestamptz,
  checksum       text,
  status         file_status_t NOT NULL DEFAULT 'UPLOADING',
  sort_order     int NOT NULL DEFAULT 0,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  deleted_at     timestamptz,
  deleted_by_id  uuid REFERENCES users(id)
);
CREATE INDEX files_album_page_idx ON files(album_id, deleted_at, status, taken_at, id);
CREATE INDEX files_album_type_idx ON files(album_id, file_type, deleted_at);
CREATE INDEX files_deleted_idx    ON files(deleted_at);
CREATE INDEX files_checksum_idx   ON files(checksum);
CREATE INDEX files_name_trgm      ON files USING gin (file_name gin_trgm_ops);

ALTER TABLE albums
  ADD CONSTRAINT albums_cover_fk FOREIGN KEY (cover_file_id) REFERENCES files(id);

-- Empty in the MVP; filled when HLS transcoding is enabled.
CREATE TABLE video_renditions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  file_id     uuid NOT NULL REFERENCES files(id) ON DELETE CASCADE,
  label       text NOT NULL,
  storage_key text NOT NULL,
  bitrate     int,
  status      file_status_t NOT NULL DEFAULT 'PROCESSING',
  UNIQUE (file_id, label)
);

CREATE TABLE upload_sessions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  file_id      uuid NOT NULL UNIQUE REFERENCES files(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES users(id),
  s3_upload_id text NOT NULL,
  part_size    int  NOT NULL,
  total_parts  int  NOT NULL,
  status       upload_status_t NOT NULL DEFAULT 'INITIATED',
  expires_at   timestamptz NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX upload_sessions_expiry_idx ON upload_sessions(status, expires_at);

-- Background jobs (thumbnails, video processing). Workers claim rows with FOR UPDATE SKIP LOCKED.
CREATE TABLE jobs (
  id          bigserial PRIMARY KEY,
  kind        text NOT NULL,
  payload     jsonb NOT NULL,
  status      text NOT NULL DEFAULT 'queued',   -- queued | running | done | failed
  attempts    int  NOT NULL DEFAULT 0,
  last_error  text,
  run_after   timestamptz NOT NULL DEFAULT now(),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX jobs_claim_idx ON jobs(status, run_after);

CREATE TABLE activity_logs (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id   uuid REFERENCES users(id),
  action     text NOT NULL,
  entity     text NOT NULL,
  entity_id  text,
  summary    text NOT NULL,
  metadata   jsonb,
  ip         text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX activity_created_idx ON activity_logs(created_at DESC);
CREATE INDEX activity_actor_idx   ON activity_logs(actor_id, created_at DESC);
CREATE INDEX activity_entity_idx  ON activity_logs(entity, entity_id);

CREATE TABLE settings (
  key        text PRIMARY KEY,
  value      jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
