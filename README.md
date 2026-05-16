# otel_flutter_command

OpenTelemetry instrumentation for
[`package:flutter_command`](https://pub.dev/packages/flutter_command) —
Thomas Burkhart's `Command` pattern for Flutter UI actions.

Adds a CLIENT-kind span around every command execution so you can see
exactly which button taps / form submits / refresh handlers are slow
and which ones throw.

## Install

```yaml
dependencies:
  flutter_command: ^4.0.0
  otel_flutter_command: ^0.1.0
```

## Use

Replace `.execute(...)` with `.executeTraced(...)` and
`.executeWithFuture(...)` with `.executeTracedWithFuture(...)`:

```dart
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:flutter_command/flutter_command.dart';
import 'package:otel_flutter_command/otel_flutter_command.dart';

// Define a command, as usual.
final saveNote = Command.createAsyncNoResult<String>(
  (text) async { await db.save(text); },
  debugName: 'saveNote',  // shown in flutter_command's own diagnostics
);

// In your button handler:
ElevatedButton(
  onPressed: () => saveNote.executeTracedWithFuture(
    textController.text,
    'saveNote',
  ),
  child: const Text('Save'),
);
```

For sync commands:

```dart
final clearForm = Command.createSyncNoParamNoResult(() {
  textController.clear();
});

ElevatedButton(
  onPressed: () => clearForm.executeTraced(null, 'clearForm'),
  child: const Text('Clear'),
);
```

## Span shape

| Attribute            | Source                                                |
|----------------------|-------------------------------------------------------|
| `command.name`       | the `spanName` you pass (defaults to `<anonymous>`)   |
| `command.system`     | hardcoded `flutter_command`                           |
| `command.result`     | `success` or `error`                                  |
| `error.type`         | exception class on throw                              |

Span name: `flutter_command <spanName>`.

The span captures the full duration of:
- `executeTraced` — from call until `execute(...)` returns (or
  throws). For async commands this is just the synchronous
  dispatch; use `executeTracedWithFuture` for the awaited duration.
- `executeTracedWithFuture` — from call until the underlying
  `Future` completes (success or error).

## Why call-site instrumentation?

`flutter_command` ships two global hooks:

- `Command.loggingHandler` — fires once at the end of execution.
  Can't measure duration.
- `Command.globalExceptionHandler` — fires when an exception
  escapes a command. Can't measure duration either.

And the per-command `results` `ValueListenable` uses
`CustomNotifierMode.normal` by default — it filters out no-op
updates with `==`. So a `createSyncNoParamNoResult` command (whose
result type is `void`) emits *no* result events at all when
executed, because the new `CommandResult` compares equal to the
initial one.

That left call-site instrumentation as the only path that reliably
captures every execution with duration. The extension methods
`executeTraced` / `executeTracedWithFuture` are the result.

## Suppression

```dart
await runWithoutFlutterCommandInstrumentationAsync(() async {
  await myCommand.executeTracedWithFuture(p, 'hot.path');  // skipped
});
```

## See also

- [`otel_get_it`](https://pub.dev/packages/otel_get_it) — Thomas
  Burkhart's service locator.
- [`otel_watch_it`](https://pub.dev/packages/otel_watch_it) —
  Thomas Burkhart's Flutter binding to `get_it`.

## License

Apache 2.0 — copyright Mindful Software LLC.
