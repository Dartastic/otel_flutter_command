# otel_flutter_command example

A login form whose submit button taps emit a span you can find in
Jaeger, Zipkin, or any OTLP backend.

```dart
// example/lib/main.dart

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_command/flutter_command.dart';
import 'package:otel_flutter_command/otel_flutter_command.dart';

class AuthService {
  Future<void> login(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (password.length < 8) throw StateError('password too short');
  }
}

late final AuthService auth;

Future<void> main() async {
  await OTel.initialize(
    serviceName: 'flutter-command-demo',
  );
  // flutter_command's default ErrorFilter expects a local `.errors`
  // listener or this global handler; without one, debug builds assert.
  Command.globalExceptionHandler = (error, stackTrace) {
    debugPrint('command failed: $error');
  };
  auth = AuthService();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: LoginPage());
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final Command<List<String>, void> login;
  final emailCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    login = Command.createAsyncNoResult<List<String>>(
      (args) => auth.login(args[0], args[1]),
      debugName: 'login',
    );
  }

  Future<void> _submit() async {
    // ✨ Span: `flutter_command login`
    //
    //    Carries `command.name=login`, `command.result=success` or
    //    `error`, and on failure `error.type` plus the exception
    //    recorded on the span. Duration is exactly the awaited
    //    Future.
    try {
      await login.executeTracedWithFuture(
        [emailCtrl.text, pwdCtrl.text],
        'login',
      );
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } catch (_) {
      // Stay on this screen; the span already captured the error.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: pwdCtrl, obscureText: true,
              decoration: const InputDecoration(labelText: 'Password')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## What you'll see

```
flutter_command login
  command.name = login
  command.system = flutter_command
  command.result = error
  error.type = StateError
  status = Error  (description: "Bad state: password too short")
```

…or on success:

```
flutter_command login
  command.name = login
  command.system = flutter_command
  command.result = success
  status = Unset  (no error)
```

Trace duration is exactly the `auth.login` Future, so if a login
suddenly gets slower, this is where you see it.
