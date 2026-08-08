# Changelog

## [0.2.0-wip]

### Changed

- Semantic conventions updated to the current OTel registry: deprecated
  attribute keys are no longer emitted (`db.system` -> `db.system.name`,
  `db.operation` -> `db.operation.name`, `rpc.system` -> `rpc.system.name`,
  with `rpc.service` folded into a fully-qualified `rpc.method`).
- Dependency floors raised to `dartastic_opentelemetry ^1.1.0-beta.12` and
  `dartastic_opentelemetry_api ^1.0.0-rc.1`. The previous floors declared
  compatibility with API versions that predate the semconv enums this
  package uses and could not actually resolve-and-compile.
- `repository` URL corrected to the canonical `Dartastic` org casing so
  pub.dev repository verification succeeds.
- `flutter_command` floor raised to `^7.0.0` (current major). Errors now
  flow through upstream's `ErrorFilter` system; register
  `Command.globalExceptionHandler` (or a local `.errors` listener) or
  debug builds assert on a failing command. Note: upstream has
  discontinued `flutter_command` in favor of `command_it`; this package
  keeps instrumenting `flutter_command` for existing apps.

### Added

- `Command.executeTraced(param, spanName)` — sync executor wrapped
  in a CLIENT-kind span.
- `Command.executeTracedWithFuture(param, spanName)` — async
  executor wrapped in a span; awaits the future before closing.
- Span shape: `flutter_command <name>` with `command.name`,
  `command.system=flutter_command`, `command.result` =
  `success` / `error`. Errors get `error.type` +
  `recordException` + `Error` status, then rethrow.
- Local `FlutterCommandSemantics` enum (implements `OTelSemantic`).
- Zone-scoped suppression via
  `runWithoutFlutterCommandInstrumentation()` / `Async()`.
- Six `flutter_test` tests using the canonical
  `_helpers/otel_test_harness.dart`.

### Design notes

- We instrument at the call site (extension methods on `Command`)
  rather than via the package's global `loggingHandler` /
  `globalExceptionHandler` hooks. The global hooks fire only at the
  *end* of execution, so they can't measure duration; and the
  per-command `results` `ValueListenable` filters no-op updates by
  `==`, which means a sync command whose result equals its initial
  value emits no event at all. Per-call instrumentation sidesteps
  both issues.
