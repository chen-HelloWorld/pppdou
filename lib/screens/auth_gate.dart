import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show ImportScreen, ink, purple, muted;
import '../services/color_engine.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.colors});

  final ColorEngine colors;

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (client.auth.currentSession != null) {
          return ImportScreen(colors: colors);
        }
        return const SignInScreen();
      },
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _message = '请输入邮箱账号和密码');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_registering) {
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        if (response.session == null && mounted) {
          setState(() => _message = '注册已提交，请检查 Supabase 的邮箱验证设置');
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = _friendlyAuthError(error.message));
    } catch (_) {
      if (mounted) setState(() => _message = '连接失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('already registered') || lower.contains('already been registered')) {
      return '这个邮箱账号已经注册，请直接登录';
    }
    if (lower.contains('invalid login credentials')) return '邮箱账号或密码不正确';
    if (lower.contains('password')) return '密码不符合要求，请至少输入 6 位';
    if (lower.contains('email')) return '请输入有效格式的邮箱账号';
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.grid_on_rounded, size: 58, color: purple),
                const SizedBox(height: 16),
                const Text('拼豆图纸', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ink)),
                const SizedBox(height: 8),
                Text(_registering ? '创建账号，保存并同步你的图纸' : '登录后查看已保存的图纸',
                    textAlign: TextAlign.center, style: const TextStyle(color: muted)),
                const SizedBox(height: 28),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: '邮箱账号', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: '密码', border: OutlineInputBorder()),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!, style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? '请稍候…' : _registering ? '注册' : '登录'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => setState(() {
                    _registering = !_registering;
                    _message = null;
                  }),
                  child: Text(_registering ? '已有账号？去登录' : '还没有账号？立即注册'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
