import 'package:flutter/material.dart';
import '../widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _password = TextEditingController();
  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrinPage(
      title: 'Login',
      child: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Email/ Username',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _user,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline),
                      hintText: 'Enter your email or username',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required field' : null,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Password',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.lock_outline),
                      hintText: 'Enter your password',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required field' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => unavailable(context, 'Forgot password'),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: brinRed, fontSize: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: brinRed,
                      padding: const EdgeInsets.all(15),
                    ),
                    onPressed: () {
                      if (_form.currentState!.validate())
                        unavailable(context, 'Login');
                    },
                    child: const Text('Login'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Secure access for container monitoring system.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: brinMuted),
          ),
        ],
      ),
    );
  }
}
