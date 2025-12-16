# PlaceOS Triggers

[![Build](https://github.com/PlaceOS/triggers/actions/workflows/build.yml/badge.svg)](https://github.com/PlaceOS/triggers/actions/workflows/build.yml)
[![CI](https://github.com/PlaceOS/triggers/actions/workflows/ci.yml/badge.svg)](https://github.com/PlaceOS/triggers/actions/workflows/ci.yml)
[![Changelog](https://img.shields.io/badge/Changelog-available-github.svg)](/CHANGELOG.md)

[PlaceOS](https://place.technology/) service handling events and conditional triggers.

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md).

## Environment Variables

### Core Configuration

- `SG_ENV` = set to `production` for production log levels (default: `development`)
- `SG_SERVER_PORT` = server port (default: `3000`)
- `SG_SERVER_HOST` = server host (default: `127.0.0.1`)
- `SG_PROCESS_COUNT` = number of processes (default: `1`)
- `REDIS_URL` = the redis connection string, defaults to `redis://localhost:6379`

### SMTP Configuration

- `SMTP_SERVER` = hostname of the SMTP server for sending emails (default: `smtp.example.com`)
- `SMTP_PORT` = port to connect to the SMTP server (default: `25`)
- `SMTP_USER` = username if any required, will not authenticate if this is left blank
- `SMTP_PASS` = password if required
- `SMTP_SECURE` = left blank for clear text, `SMTPS` for a TLS connection, `STARTTLS` for negotiating TLS on an initial clear text connection

### Telemetry (PlaceOS Pulse)

- `PLACE_PULSE_ENABLED` = enable telemetry (set to `1` or `true`)
- `PLACE_DOMAIN` = domain for telemetry instance
- `PLACE_PULSE_INSTANCE_EMAIL` = email for telemetry instance

### Trigger Intervals

- `UPDATE_CHECK_INTERVAL` = driver update check interval (default: `2h`)
- `GRAPH_SECRET_CHECK_INTERVAL` = graph secret expiry check interval (default: `24h`)
- `LOKI_SEARCH_CHECK_INTERVAL` = Loki error search interval (default: `1h`)
- `LOKI_SEARCH_WINDOW` = Loki search time window (default: `24h`)

**Duration Format**: Intervals support flexible formats like `5m`, `1h20m`, `2h30m45s`, etc.
**Note**: Invalid formats (like `"5"` without postfix, `"invalid"`, etc.) will be treated as zero duration, which may cause unexpected behavior. Always include proper time units (`h`, `m`, `s`).

## Bindings

Trigger state is exposed through the system like a regular module.

```

# Binding
_TRIGGER_.trig-systemtrigid

```

This exposes the following data:

```

{
  "triggered": true / false,
  "trigger_count": 34,
  "action_errors": 2,
  "comparison_errors": 0,
  "conditions": {
    "comparison_1": true / false,
    "time_1": true / false
  }
}

```
