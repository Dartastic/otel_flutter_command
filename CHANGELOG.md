# Changelog

## [0.1.0-beta.1-wip]

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
