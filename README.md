# PlaceOS Triggers

[![Build Dev Image](https://github.com/PlaceOS/triggers/actions/workflows/build-dev-image.yml/badge.svg)](https://github.com/PlaceOS/triggers/actions/workflows/build-dev-image.yml)
[![CI](https://github.com/PlaceOS/triggers/actions/workflows/ci.yml/badge.svg)](https://github.com/PlaceOS/triggers/actions/workflows/ci.yml)

PlaceOS service handling events and conditional triggers.

## EVN Vars

* `SG_ENV` = set to `production` for production log levels
* `SMTP_SERVER` = hostname of the SMTP server for sending emails. i.e. smtp.example.com
* `SMTP_PORT` = port to connect to the SMTP server
* `SMTP_USER` = username if any required, will not authenticate if this is left blank
* `SMTP_PASS` = password if required
* `SMTP_SECURE` = left blank for clear text, `SMTPS` for a TLS connection, `STARTTLS` for negotiating TLS on an initial clear text connection
* `REDIS_URL` = the redis connection string, defaults to `redis://localhost:6379`

## Testing

`crystal spec`

## Compiling

`shards build`

## Deploying

Once compiled you are left with a binary `triggers`

* for help `./triggers --help`
* viewing routes `./triggers --routes`
* run on a different port or host `./triggers -b 0.0.0.0 -p 80`

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
