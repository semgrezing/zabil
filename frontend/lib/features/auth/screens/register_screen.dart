import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

// ─── Figma design tokens ──────────────────────────────────────────────────────
const _kBg        = Color(0xFF161616);
const _kInputFill = Color(0x26FFFFFF); // rgba(255,255,255,0.15)
const _kHint      = Color(0xFFA8A8A8);
const _kBtnText   = Color(0xFF333333);
const _kSecondary = Color(0xFFA8A8A8);
const _kTitle     = Color(0xFFFCFFFF);
const _kError     = Color(0xFFC93838);
const _kRadius    = 16.0;
const _kBtnH      = 56.0;
const _kWidth     = 361.0;

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool  _obscure      = true;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    await ref.read(authStateProvider.notifier).register(
      _usernameCtrl.text.trim(),
      _passwordCtrl.text,
    );
    if (!mounted) return;
    ref.read(authStateProvider).whenOrNull(
      error: (e, _) => setState(() => _error = _parseError(e)),
    );
  }

  String _parseError(Object e) {
    final s = e.toString();
    if (s.contains('уже существует')) return 'Это имя пользователя занято';
    if (s.contains('Connection')) return 'Нет соединения с сервером';
    return 'Произошла ошибка. Попробуйте ещё раз';
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authStateProvider).isLoading;
    return Scaffold(
      backgroundColor: _kBg,
      body: LayoutBuilder(
        builder: (ctx, constraints) => constraints.maxWidth >= 768
            ? _desktop(context, loading)
            : _mobile(context, loading),
      ),
    );
  }

  // ── Desktop: центрированная форма + кнопка назад сверху-слева ────────────────
  Widget _desktop(BuildContext context, bool loading) {
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: SizedBox(
              width: _kWidth,
              child: _formContent(context, loading),
            ),
          ),
        ),
        Positioned(
          top: 32,
          left: 16,
          child: SafeArea(child: _backButton(context)),
        ),
      ],
    );
  }

  // ── Mobile: декоративный фон + кнопка назад + форма снизу ───────────────────
  Widget _mobile(BuildContext context, bool loading) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _mobileBackground(),
        SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 32,
            ),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.44),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _formContent(context, loading),
              ),
            ],
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          child: _backButton(context),
        ),
      ],
    );
  }

  Widget _mobileBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.4, -0.5),
              radius: 1.6,
              colors: [
                Color(0xFF2E2F48),
                Color(0xFF1C1C2C),
                Color(0xFF161616),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        Positioned(
          right: -30,
          top: 50,
          child: Container(
            width: 240,
            height: 240,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x554F42D0),
                  blurRadius: 120,
                  spreadRadius: 40,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: -10,
          top: 100,
          child: Container(
            width: 170,
            height: 170,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x351B9BA4),
                  blurRadius: 90,
                  spreadRadius: 30,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _backButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/login'),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _kInputFill,
          borderRadius: BorderRadius.circular(_kRadius),
        ),
        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
      ),
    );
  }

  // ── Форма ──────────────────────────────────────────────────────────────────────
  Widget _formContent(BuildContext context, bool loading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'регистрация',
            style: TextStyle(
              color: _kTitle,
              fontSize: 40,
              fontWeight: FontWeight.w600,
              letterSpacing: -2,
              height: 1,
            ),
          ),
          const SizedBox(height: 32),
          _AuthInput(
            controller: _usernameCtrl,
            hint: 'Никнейм',
            validator: (v) {
              if ((v ?? '').isEmpty) return 'Введите никнейм';
              if (v!.length < 3) return 'Минимум 3 символа';
              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
                return 'Только буквы, цифры и _';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _AuthInput(
            controller: _passwordCtrl,
            hint: 'Пароль',
            obscureText: _obscure,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: _kHint,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            validator: (v) {
              if ((v ?? '').isEmpty) return 'Введите пароль';
              if (v!.length < 8) return 'Минимум 8 символов';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _AuthInput(
            controller: _confirmCtrl,
            hint: 'Пароль снова',
            obscureText: _obscure,
            validator: (v) {
              if ((v ?? '').isEmpty) return 'Подтвердите пароль';
              if (v != _passwordCtrl.text) return 'Пароли не совпадают';
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: _kError, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: _kBtnH,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _kBtnText,
                disabledBackgroundColor: const Color(0x80FFFFFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kRadius),
                ),
                elevation: 0,
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_kBtnText),
                      ),
                    )
                  : const Text(
                      'зарегистрироваться',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => context.go('/login'),
              style: TextButton.styleFrom(
                foregroundColor: _kSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text(
                'уже есть аккаунт? войти',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Glassmorphism input field ────────────────────────────────────────────────
class _AuthInput extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _AuthInput({
    this.controller,
    required this.hint,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kHint, fontSize: 16),
        filled: true,
        fillColor: _kInputFill,
        contentPadding: EdgeInsets.only(
          left: 16,
          right: suffixIcon != null ? 4 : 16,
          top: 18,
          bottom: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: const BorderSide(color: Color(0x4DFFFFFF), width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: const BorderSide(color: _kError, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: const BorderSide(color: _kError, width: 1),
        ),
        errorStyle: const TextStyle(color: _kError, fontSize: 12, height: 1.5),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
