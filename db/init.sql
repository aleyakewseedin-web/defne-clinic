-- Defne Family Clinic: schema and seed data
-- Runs once, the first time the database container starts.

CREATE EXTENSION IF NOT EXISTS btree_gist;  -- lets the exclusion constraint compare staff_id with "="
CREATE EXTENSION IF NOT EXISTS pgcrypto;    -- password hashing for the seed users

CREATE TYPE user_role      AS ENUM ('customer', 'staff', 'administrator');
CREATE TYPE booking_status AS ENUM ('confirmed', 'cancelled', 'completed', 'no_show');
CREATE TYPE queue_status   AS ENUM ('waiting', 'in_service', 'done', 'left');

CREATE TABLE users (
  id                 SERIAL PRIMARY KEY,
  role               user_role   NOT NULL,
  name               TEXT        NOT NULL,
  email              TEXT        NOT NULL UNIQUE,
  phone              TEXT,
  password_hash      TEXT        NOT NULL,
  preferred_language TEXT        NOT NULL DEFAULT 'en' CHECK (preferred_language IN ('en', 'tr')),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE services (
  id               SERIAL PRIMARY KEY,
  name             TEXT    NOT NULL UNIQUE,
  duration_minutes INT     NOT NULL CHECK (duration_minutes > 0),
  active           BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE staff_services (
  staff_id   INT NOT NULL REFERENCES users(id),
  service_id INT NOT NULL REFERENCES services(id),
  PRIMARY KEY (staff_id, service_id)
);

-- weekday: 0 = Monday ... 6 = Sunday
CREATE TABLE opening_hours (
  weekday    SMALLINT PRIMARY KEY CHECK (weekday BETWEEN 0 AND 6),
  open_time  TIME NOT NULL,
  close_time TIME NOT NULL,
  CHECK (open_time < close_time)
);

-- A day the clinic has explicitly closed (or opened outside the normal pattern)
CREATE TABLE clinic_days (
  day     DATE PRIMARY KEY,
  is_open BOOLEAN NOT NULL
);

CREATE TABLE staff_availability (
  id         SERIAL PRIMARY KEY,
  staff_id   INT      NOT NULL REFERENCES users(id),
  weekday    SMALLINT NOT NULL CHECK (weekday BETWEEN 0 AND 6),
  start_time TIME     NOT NULL,
  end_time   TIME     NOT NULL,
  CHECK (start_time < end_time)
);

CREATE TABLE leave_blocks (
  id         SERIAL PRIMARY KEY,
  staff_id   INT         NOT NULL REFERENCES users(id),
  start_time TIMESTAMPTZ NOT NULL,
  end_time   TIMESTAMPTZ NOT NULL,
  reason     TEXT,
  CHECK (start_time < end_time)
);

CREATE TABLE bookings (
  id           SERIAL PRIMARY KEY,
  customer_id  INT            NOT NULL REFERENCES users(id),
  staff_id     INT            NOT NULL REFERENCES users(id),
  service_id   INT            NOT NULL REFERENCES services(id),
  start_time   TIMESTAMPTZ    NOT NULL,
  end_time     TIMESTAMPTZ    NOT NULL,
  status       booking_status NOT NULL DEFAULT 'confirmed',
  created_by   INT            NOT NULL REFERENCES users(id),
  cancelled_by INT            REFERENCES users(id),
  cancelled_at TIMESTAMPTZ,
  created_at   TIMESTAMPTZ    NOT NULL DEFAULT now(),
  CHECK (start_time < end_time),

  -- THE CORE RULE (FR-4.1, FR-4.3, FR-4.4):
  -- two confirmed bookings of one staff member can never overlap.
  -- The range is half-open '[)', so 09:30-10:00 and 10:00-10:30 do not clash.
  -- Cancelled bookings are ignored, so cancelling frees the interval.
  CONSTRAINT no_overlapping_confirmed_bookings
    EXCLUDE USING gist (
      staff_id WITH =,
      tstzrange(start_time, end_time, '[)') WITH &&
    ) WHERE (status = 'confirmed')
);

CREATE TABLE queue_entries (
  id            SERIAL PRIMARY KEY,
  day           DATE         NOT NULL,
  queue_number  INT          NOT NULL,
  customer_id   INT          REFERENCES users(id),
  walk_in_name  TEXT,
  status        queue_status NOT NULL DEFAULT 'waiting',
  served_by     INT          REFERENCES users(id),
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  UNIQUE (day, queue_number),
  CHECK (customer_id IS NOT NULL OR walk_in_name IS NOT NULL)
);

CREATE TABLE reminders (
  id          SERIAL PRIMARY KEY,
  booking_id  INT         NOT NULL UNIQUE REFERENCES bookings(id) ON DELETE CASCADE,
  customer_id INT         NOT NULL REFERENCES users(id),
  message     TEXT        NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE audit_events (
  id         SERIAL PRIMARY KEY,
  actor_id   INT         REFERENCES users(id),
  action     TEXT        NOT NULL,
  target     TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------
-- Seed data (FR-1.1). All three passwords are: password123
-- ---------------------------------------------------------------
INSERT INTO users (role, name, email, phone, password_hash) VALUES
  ('administrator', 'Admin Demir',     'admin@defne.test',    NULL,           crypt('password123', gen_salt('bf'))),
  ('staff',         'Nurse Elif Kaya', 'staff@defne.test',    '0532 000 0002', crypt('password123', gen_salt('bf'))),
  ('customer',      'Ayse Yilmaz',     'customer@defne.test', '0532 000 0003', crypt('password123', gen_salt('bf')));

INSERT INTO services (name, duration_minutes) VALUES
  ('General check-up',     30),
  ('Blood pressure check', 15),
  ('Vaccination',          20);

INSERT INTO staff_services (staff_id, service_id)
  SELECT u.id, s.id FROM users u CROSS JOIN services s WHERE u.email = 'staff@defne.test';

-- Monday to Friday, 09:00-17:00
INSERT INTO opening_hours (weekday, open_time, close_time)
  SELECT d, '09:00', '17:00' FROM generate_series(0, 4) AS d;

INSERT INTO staff_availability (staff_id, weekday, start_time, end_time)
  SELECT u.id, d, '09:00', '17:00'
  FROM users u CROSS JOIN generate_series(0, 4) AS d
  WHERE u.email = 'staff@defne.test';
