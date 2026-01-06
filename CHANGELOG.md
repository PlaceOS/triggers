## v1.18.2 (2026-01-06)

### Refactor

- **loki_search_errors**: [PPT-2344] extract timestamp from entry object instead of stream labels ([#52](https://github.com/PlaceOS/triggers/pull/52))

## v1.18.1 (2025-12-16)

### Refactor

- [PPT-2325] optimize loki search trigger ([#51](https://github.com/PlaceOS/triggers/pull/51))

## v1.18.0 (2025-10-22)

### Feat

- add rest-api health check to triggers

## v1.17.1 (2025-04-14)

### Fix

- **Dockerfile**: make git certificate store is explicit

## v1.17.0 (2024-06-20)

### Feat

- Make loki-search trigger Loki presence dependent ([#48](https://github.com/PlaceOS/triggers/pull/48))

## v1.16.0 (2024-05-21)

### Feat

- PPT-1322 Trigger for periodic check of mods runtime error ([#47](https://github.com/PlaceOS/triggers/pull/47))

## v1.15.0 (2024-04-12)

### Feat

- migrate to redis service manager ([#46](https://github.com/PlaceOS/triggers/pull/46))

## v1.14.0 (2024-04-10)

### Feat

- PPT-1224 Add trigger to periodically check for secret expiry ([#45](https://github.com/PlaceOS/triggers/pull/45))

## v1.13.0 (2023-11-29)

### Feat

- PPT-1038 Job to identify version upgrade for drivers ([#44](https://github.com/PlaceOS/triggers/pull/44))

## v1.12.0 (2023-09-08)

### Feat

- refactor triggers to use place resource ([#43](https://github.com/PlaceOS/triggers/pull/43))

## v1.11.2 (2023-07-04)

### Fix

- **eventbus**: handle read replica race conditions

## v1.11.1 (2023-07-04)

### Fix

- **eventbus**: handle read replica race conditions

## v1.11.0 (2023-06-26)

### Feat

- **shard.lock**: bump opentelemetry-instrumentation.cr

## v1.10.0 (2023-05-09)

### Feat

- **shard.lock**: bump deps

## v1.9.1 (2023-01-09)

### Fix

- **state**: execute on edge modules ([#42](https://github.com/PlaceOS/triggers/pull/42))

## v1.9.0 (2022-09-13)

### Feat

- update pulse client ([#38](https://github.com/PlaceOS/triggers/pull/38))

## v1.8.0 (2022-09-08)

### Feat

- **shards**: bump libs ([#37](https://github.com/PlaceOS/triggers/pull/37))

## v1.7.1 (2022-09-08)

### Fix

- **Dockerfile**: revert static build ([#36](https://github.com/PlaceOS/triggers/pull/36))

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
