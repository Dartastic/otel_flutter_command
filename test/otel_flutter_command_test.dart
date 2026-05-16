// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:flutter_command/flutter_command.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otel_flutter_command/otel_flutter_command.dart';

import 'package:dartastic_opentelemetry/testing.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_flutter_command-test',
    );
    spans = harness.spans;
  });

  setUp(() {
    harness.clear();
  });

  test('sync executeTraced emits a span with command.result=success', () {
    final cmd = Command.createSyncNoParamNoResult(() {});
    cmd.executeTraced(null, 'do.thing');

    final span = spans.findSpanByName('flutter_command do.thing');
    expect(span, isNotNull);
    final attrs = {for (final a in span!.attributes.toList()) a.key: a.value};
    expect(attrs['command.name'], 'do.thing');
    expect(attrs['command.system'], 'flutter_command');
    expect(attrs['command.result'], 'success');
    expect(span.status, isNot(SpanStatusCode.Error));
  });

  test('async executeTracedWithFuture spans the awaited future', () async {
    final cmd = Command.createAsyncNoParamNoResult(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await cmd.executeTracedWithFuture(null, 'do.async.thing');

    final span = spans.findSpanByName('flutter_command do.async.thing');
    expect(span, isNotNull);
    final attrs = {for (final a in span!.attributes.toList()) a.key: a.value};
    expect(attrs['command.result'], 'success');
  });

  test('async throw → span.status=Error + error.type attr', () async {
    final cmd = Command.createAsyncNoParamNoResult(() async {
      throw StateError('boom');
    });
    try {
      await cmd.executeTracedWithFuture(null, 'do.async.boom');
    } catch (_) {
      // Either rethrown or swallowed by catchAlways; we don't care.
    }
    final span = spans.findSpanByName('flutter_command do.async.boom');
    expect(span, isNotNull);
    expect(span!.status, SpanStatusCode.Error);
    final attrs = {for (final a in span.attributes.toList()) a.key: a.value};
    expect(attrs['command.result'], 'error');
    expect(attrs['error.type'], 'StateError');
  });

  test('default span name is <anonymous>', () {
    final cmd = Command.createSyncNoParamNoResult(() {});
    cmd.executeTraced();
    expect(
      spans.findSpanByName('flutter_command <anonymous>'),
      isNotNull,
    );
  });

  test('zone-scoped suppression skips spans', () async {
    final cmd = Command.createSyncNoParamNoResult(() {});
    await runWithoutFlutterCommandInstrumentationAsync(() async {
      cmd.executeTraced(null, 'do.quiet');
    });
    expect(spans.findSpansStartingWith('flutter_command'), isEmpty);
  });

  test('sync command with TParam runs and emits a span', () {
    final received = <int>[];
    final cmd = Command.createSyncNoResult<int>(received.add);
    cmd.executeTraced(42, 'add.int');
    expect(received, [42]);
    expect(
      spans.findSpanByName('flutter_command add.int'),
      isNotNull,
    );
  });
}
