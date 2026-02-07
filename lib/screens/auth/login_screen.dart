import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _isLogin = true;
  String _error = '';

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Sign In' : 'Sign Up')),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (val) => val!.isEmpty ? 'Enter an email' : null,
                onChanged: (val) => setState(() => _email = val),
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (val) => val!.length < 6 ? 'Enter a password 6+ chars long' : null,
                onChanged: (val) => setState(() => _password = val),
              ),
              const SizedBox(height: 12),
              Text(
                _error,
                style: const TextStyle(color: Colors.red, fontSize: 14.0),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                child: Text(_isLogin ? 'Sign In' : 'Register'),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    try {
                      if (_isLogin) {
                        await authService.signIn(_email, _password);
                      } else {
                        await authService.signUp(_email, _password);
                      }
                    } catch (e) {
                      setState(() {
                        _error = e.toString();
                      });
                    }
                  }
                },
              ),
              TextButton(
                child: Text(_isLogin ? 'Need an account? Register' : 'Have an account? Sign In'),
                onPressed: () => setState(() => _isLogin = !_isLogin),
              )
            ],
          ),
        ),
      ),
    );
  }
}
