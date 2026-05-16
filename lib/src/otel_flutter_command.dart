// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:flutter_command/flutter_command.dart' as fc;

import 'otel_flutter_command_suppression.dart';

const _tracerName = 'otel_flutter_command';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Typed attribute keys for flutter_command spans.
///
/// `flutter_command` is a Command-pattern wrapper for UI actions
/// (button taps, form submits, refresh handlers, etc.). No upstream
/// OTel semconv exists for it yet; these `command.*` keys are
/// package-local until a proposal lands.
enum FlutterCommandSemantics implements OTelSemantic {
  /// `command.name` — the span name supplied at the call site (or
  /// `<anonymous>` when none was given). `flutter_command` keeps its
  /// own `debugName` private, so the wrapper can't read it.
  commandName('command.name'),

  /// `command.system` — always `flutter_command` for spans we emit.
  commandSystem('command.system'),

  /// `command.result` — `success` / `error`.
  commandResult('command.result');

  const FlutterCommandSemantics(this.key);

  @override
  final String key;

  @override
  String toString() => key;
}

/// Traced operations on [fc.Command].
///
/// `flutter_command`'s state propagates via `CustomValueNotifier`
/// instances that filter "no-op" updates by `==`. That means a sync
/// command whose result equals its initial value doesn't even fire
/// a `results` listener — so we can't reliably observe execution by
/// listening from the outside. Instead, instrument at the *call
/// site*: replace `cmd.execute(...)` with `cmd.executeTraced(...)`
/// and replace `cmd.executeWithFuture(...)` with
/// `cmd.executeTracedWithFuture(...)`.
///
/// Both produce a CLIENT-kind span named `flutter_command <name>`
/// (defaults to `<anonymous>`) carrying `command.name`,
/// `command.system=flutter_command`, and `command.result` =
/// `success` / `error`. Errors get `error.type` +
/// `recordException` + `Error` status, then rethrow.
extension OTelCommand<TParam, TResult> on fc.Command<TParam, TResult> {
  /// Synchronous-style executor: opens a span, calls [execute],
  /// closes the span when [execute] returns or throws.
  ///
  /// Note: `flutter_command` swallows exceptions on async commands
  /// by default (`catchAlwaysDefault = true`). This wrapper only
  /// sees a span as "error" if the exception escapes; for async
  /// commands prefer [executeTracedWithFuture], which awaits and
  /// can see swallowed errors via the [fc.CommandResult].
  void executeTraced([TParam? param, String spanName = '<anonymous>']) {
    if (flutterCommandInstrumentationSuppressed()) {
      execute(param);
      return;
    }
    final span = _openSpan(spanName);
    try {
      execute(param);
    } catch (e, st) {
      _endError(span, e, st);
      rethrow;
    }
    // Sync commands have completed by now; async commands have
    // started. Look at the result to decide success vs error.
    _endFromResult(span, results.value);
  }

  /// Async-style executor: opens a span, awaits [executeWithFuture],
  /// closes the span when the future completes or throws.
  Future<TResult> executeTracedWithFuture([
    TParam? param,
    String spanName = '<anonymous>',
  ]) async {
    if (flutterCommandInstrumentationSuppressed()) {
      return executeWithFuture(param);
    }
    final span = _openSpan(spanName);
    try {
      final result = await executeWithFuture(param);
      _endFromResult(span, results.value);
      return result;
    } catch (e, st) {
      _endError(span, e, st);
      rethrow;
    }
  }
}

Span _openSpan(String name) {
  return _tracer().startSpan(
    'flutter_command $name',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(<String, Object>{
      FlutterCommandSemantics.commandName.key: name,
      FlutterCommandSemantics.commandSystem.key: 'flutter_command',
    }),
  );
}

void _endFromResult(Span span, fc.CommandResult result) {
  if (result.hasError) {
    final err = result.error;
    span.addAttributes(
      OTel.attributes([
        OTel.attributeString(
          FlutterCommandSemantics.commandResult.key,
          'error',
        ),
        if (err != null)
          OTel.attributeString(
            ErrorResource.errorType.key,
            err.runtimeType.toString(),
          ),
      ]),
    );
    if (err != null) span.recordException(err);
    span.setStatus(SpanStatusCode.Error, err?.toString() ?? 'command error');
  } else {
    span.addAttributes(
      OTel.attributes([
        OTel.attributeString(
          FlutterCommandSemantics.commandResult.key,
          'success',
        ),
      ]),
    );
  }
  span.end();
}

void _endError(Span span, Object error, StackTrace stackTrace) {
  span.addAttributes(
    OTel.attributes([
      OTel.attributeString(
        FlutterCommandSemantics.commandResult.key,
        'error',
      ),
      OTel.attributeString(
        ErrorResource.errorType.key,
        error.runtimeType.toString(),
      ),
    ]),
  );
  span.recordException(error, stackTrace: stackTrace);
  span.setStatus(SpanStatusCode.Error, error.toString());
  span.end();
}
