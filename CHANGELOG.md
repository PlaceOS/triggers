## v1.7.0 (2022-09-03)

### Feat

- update to be self documenting ([#35](https://github.com/PlaceOS/triggers/pull/35))

## v1.6.0 (2022-09-03)

### Feat

- add ARM support ([#34](https://github.com/PlaceOS/triggers/pull/34))

## v1.5.3 (2022-05-03)

### Fix

- **telemetry**: ensure `Instrument` in scope

## v1.5.2 (2022-05-03)

### Fix

- update `placeos-log-backend`

## v1.5.1 (2022-04-28)

### Fix

- **telemetry**: seperate telemetry file

## v1.5.0 (2022-04-27)

### Feat

- **logging**: configure OpenTelemetry

## v1.4.0 (2022-04-26)

### Feat

- **logging**: add configuration by LOG_LEVEL env var

## v1.3.4 (2022-04-08)

### Fix

- bump placeos-models to 8.1.0 ([#27](https://github.com/PlaceOS/triggers/pull/27))

## v1.3.3 (2022-03-02)

### Refactor

- **loader**: DRY through abstract inheritance ([#24](https://github.com/PlaceOS/triggers/pull/24))

## v1.3.2 (2022-03-01)

### Fix

- bump placeos-pulse

## v1.3.1 (2022-03-01)

### Feat

- **pulse**: add telemetry to triggers service ([#17](https://github.com/PlaceOS/triggers/pull/17))
- conform to PlaceOS::Model::Version
- add support for timezones in crons
- **mapping**: add `state_for?`
- use placeos log backend
- update service to use crystal 1.0.0
- add logstash support
- update to driver 3.6

### Fix

- **pulse**: update for placeos-pulse 0.13.0 ([#23](https://github.com/PlaceOS/triggers/pull/23))
- docker healthcheck
- Dockerfile + specs
- **logging**: set Log progname
- **logging**: increase severity of messages to sentry
- **config**: small typo
- **mapping**: delete key for trigger in remove_instance
- **app**: consistent logging on start-up
- **spec**: with minor cleanups during investigation
- **Dockerfile**: missing override yml
- dev builds
- minor typo

### Refactor

- central build CI ([#21](https://github.com/PlaceOS/triggers/pull/21))
- **logging**: add namespace
- **mapping**: remove `with_instance`
- **mapping**: remove `with_cache`
- **mapping**: simplify api
- **state**: cleanup
- use placeos-resource

## v1.1.2 (2020-09-09)

### Feat

- **state**: implement database driven debounce period
- add secrets and update to crystal 0.35.1
- update to crystal 0.35
- expose additional state and improve node discovery
- add spec and debugging output
- **Dockerfile**: lock it down
- update to crystal 0.34
- add support for crystal 0.34
- **Dockerfile**: build images using alpine
- **docker**: build minimal image
- add webhook support
- basic triggers implemented

### Fix

- **config**: update to 0.35 logging
- use `placeos-driver`
- **constants**: improved version extraction
- **Docker**: use `-c` flag for health check
- **Dockerfile**: include the hosts file in image
- **Dockerfile**: bump crystal version and add error trace
- **Dockerfile**: spelling mistake --relese
- spawn in same thread in anticipation of multithreading

### Refactor

- rename `placeos-triggers`
- `ACAEngine` -> `PlaceOS`, `engine-triggers` -> `triggers`
