import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/authentication/social_auth.dart';
import 'package:pelevo/features/onboarding/onboarding_progress.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/profile/legal_links.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _hidden = true;
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthPage(
    brand: true,
    title: 'Welcome back',
    subtitle: 'Sign in to continue',
    children: [
      _Field(
        label: 'Email',
        hint: 'Enter your email',
        icon: Icons.alternate_email_rounded,
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
      ),
      _Field(
        label: 'Password',
        hint: 'Enter your password',
        icon: Icons.lock_outline_rounded,
        controller: _password,
        autofillHints: const [AutofillHints.password],
        obscure: _hidden,
        suffix: IconButton(
          tooltip: _hidden ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _hidden = !_hidden),
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => context.go('/screen/auth-forgot-password'),
          child: const Text(
            'Forgot password?',
            style: TextStyle(color: PelevoColors.red),
          ),
        ),
      ),
      PelevoButton(
        label:
            ref.watch(authFormProvider).submitting ? 'Signing In…' : 'Sign In',
        onPressed: ref.watch(authFormProvider).submitting ? null : _submit,
      ),
      if (ref.watch(authFormProvider).failure case final failure?)
        _AuthError(failure.message, requestId: failure.requestId),
      TextButton(
        onPressed: () => context.go('/screen/auth-verify-number'),
        child: const Text('Sign in with an email code'),
      ),
      const _DividerLabel('or continue with'),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showsGoogleSignIn)
            const _SocialButton('Google', Icons.g_mobiledata_rounded),
          if (showsAppleSignIn)
            const _SocialButton('Apple', Icons.apple_rounded),
          const _SocialButton('Facebook', Icons.facebook_rounded),
        ],
      ),
      _TextAction(
        prefix: "Don't have an account? ",
        action: 'Create one',
        onTap: () => context.go('/screen/auth-create-account'),
      ),
    ],
  );

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@') || _password.text.isEmpty) {
      context.showPelevoMessage('Enter a valid email and password');
      return;
    }
    final success = await ref
        .read(authFormProvider.notifier)
        .login(email, _password.text);
    if (!success && mounted) {
      final failure = ref.read(authFormProvider).failure;
      if (failure?.code == 'EMAIL_UNVERIFIED') {
        context.go(
          Uri(
            path: '/screen/auth-verify-number',
            queryParameters: {
              'email': email.toLowerCase(),
              'purpose': 'email_verification',
            },
          ).toString(),
        );
      }
      return;
    }
    if (success && mounted) {
      await applyPendingOnboardingDraft(ref);
      if (!mounted) return;
      final destination = GoRouterState.of(context).uri.queryParameters['from'];
      final uri = destination == null ? null : Uri.tryParse(destination);
      final path = uri?.path ?? '';
      final lastSegment =
          uri != null && uri.pathSegments.isNotEmpty
              ? uri.pathSegments.last
              : '';
      final allowedDeepLink =
          path.startsWith('/screen/') ||
          path.startsWith('/episodes/') ||
          path.startsWith('/shows/') ||
          path.startsWith('/reels/') ||
          path.startsWith('/creators/') ||
          path.startsWith('/s/');
      context.go(
        uri != null &&
                !uri.hasScheme &&
                !uri.hasAuthority &&
                allowedDeepLink &&
                !lastSegment.startsWith('auth-')
            ? uri.toString()
            : '/screen/home-feed',
      );
    }
  }
}

class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  bool _accepted = false;
  final _handle = TextEditingController();
  bool _hidden = true;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthPage(
    back: true,
    title: 'Create Account',
    subtitle: 'Fill in your details to get started',
    children: [
      _Field(
        label: 'Full name',
        hint: 'Enter your full name',
        icon: Icons.person_outline_rounded,
        controller: _name,
        autofillHints: const [AutofillHints.name],
      ),
      _Field(
        label: 'Email',
        hint: 'Enter your email',
        icon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
        controller: _email,
        autofillHints: const [AutofillHints.email],
      ),
      _Field(
        controller: _handle,
        label: 'Username',
        hint: 'letters, numbers, _ or - (no @)',
        icon: Icons.alternate_email_rounded,
      ),
      _Field(
        label: 'Password',
        hint: 'Create a password',
        icon: Icons.lock_outline_rounded,
        controller: _password,
        autofillHints: const [AutofillHints.newPassword],
        obscure: _hidden,
        suffix: IconButton(
          tooltip: _hidden ? 'Show passwords' : 'Hide passwords',
          onPressed: () => setState(() => _hidden = !_hidden),
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off,
          ),
        ),
      ),
      _Field(
        label: 'Confirm password',
        hint: 'Confirm your password',
        icon: Icons.lock_outline_rounded,
        controller: _confirmation,
        autofillHints: const [AutofillHints.newPassword],
        obscure: _hidden,
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _accepted,
        activeColor: PelevoColors.yellow,
        checkColor: Colors.black,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (value) => setState(() => _accepted = value ?? false),
        title: const PelevoPublicLegalNotice(
          lead: 'I agree to the',
          linkColor: PelevoColors.yellow,
        ),
      ),
      PelevoButton(
        label:
            ref.watch(authFormProvider).submitting
                ? 'Creating Account…'
                : 'Create Account',
        color: PelevoColors.yellow,
        foregroundColor: Colors.black,
        onPressed:
            _accepted && !ref.watch(authFormProvider).submitting
                ? _submit
                : null,
      ),
      if (ref.watch(authFormProvider).failure case final failure?)
        _AuthError(failure.message, requestId: failure.requestId),
      _TextAction(
        prefix: 'Already have an account? ',
        action: 'Sign in',
        onTap: () => context.go('/screen/auth-sign-in'),
      ),
    ],
  );

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        !_email.text.contains('@') ||
        _password.text.length < 8) {
      context.showPelevoMessage(
        'Complete all fields with a valid email and password',
      );
      return;
    }
    if (_password.text != _confirmation.text) {
      context.showPelevoMessage('Passwords do not match');
      return;
    }
    final handle = normalizeHandle(_handle.text);
    if (_handle.text.trim().isNotEmpty &&
        (handle == null ||
            handle.length < 3 ||
            !RegExp(r'^[a-z0-9_-]+$').hasMatch(handle))) {
      context.showPelevoMessage(
        'Username must be 3–30 characters: letters, numbers, dashes or underscores only',
      );
      return;
    }
    final success = await ref
        .read(authFormProvider.notifier)
        .register(
          _name.text,
          _email.text,
          _password.text,
          _confirmation.text,
          handle,
        );
    if (success && mounted) {
      context.go(
        Uri(
          path: '/screen/auth-verify-number',
          queryParameters: {
            'email': _email.text.trim().toLowerCase(),
            'purpose': 'email_verification',
          },
        ).toString(),
      );
    }
  }
}

class VerifyNumberScreen extends ConsumerStatefulWidget {
  const VerifyNumberScreen({super.key});
  @override
  ConsumerState<VerifyNumberScreen> createState() => _VerifyNumberScreenState();
}

class _VerifyNumberScreenState extends ConsumerState<VerifyNumberScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false;
  bool _sending = false;
  bool _routeReady = false;
  String _purpose = 'login';
  ApiFailure? _failure;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeReady) return;
    _routeReady = true;
    final params = GoRouterState.of(context).uri.queryParameters;
    final email = params['email']?.trim() ?? '';
    if (params['purpose'] == 'email_verification') {
      _purpose = 'email_verification';
    }
    if (email.isNotEmpty) {
      _email.text = email;
      if (_purpose == 'email_verification') _sent = true;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    if (!_email.text.contains('@')) {
      context.showPelevoMessage('Enter a valid email address');
      return;
    }
    setState(() {
      _sending = true;
      _failure = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .sendCode(_email.text, purpose: _purpose);
      if (mounted) setState(() => _sent = true);
    } on DioException catch (error) {
      if (mounted) setState(() => _failure = apiFailureFromDio(error));
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _failure = error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text)) {
      context.showPelevoMessage('Enter the six-digit code from your email');
      return;
    }
    final verified = await ref
        .read(authFormProvider.notifier)
        .verifyCode(_email.text, _code.text, purpose: _purpose);
    if (mounted && verified) {
      if (_purpose == 'email_verification') {
        context.go('/screen/auth-account-created');
        return;
      }
      await applyPendingOnboardingDraft(ref);
      if (mounted) context.go('/screen/home-feed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authFormProvider);
    final failure = _failure ?? form.failure;
    return _AuthPage(
      back: true,
      title: 'Verify your email',
      subtitle:
          _sent
              ? 'Enter the 6-digit code sent to\n${_email.text.trim()}'
              : 'Sign in with a code sent to your email',
      children: [
        _Field(
          label: 'Email',
          hint: 'Enter your email address',
          icon: Icons.email_outlined,
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          enabled: !_sent && !_sending,
          autofillHints: const [AutofillHints.email],
        ),
        if (_sent)
          _Field(
            label: 'Verification code',
            hint: '6-digit code',
            icon: Icons.lock_outline,
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
          ),
        if (failure != null)
          _AuthError(failure.message, requestId: failure.requestId),
        PelevoButton(
          label:
              _sending || form.submitting
                  ? 'Please wait…'
                  : _sent
                  ? 'Verify'
                  : 'Send Code',
          color: PelevoColors.green,
          onPressed:
              _sending || form.submitting
                  ? null
                  : _sent
                  ? _verify
                  : _send,
        ),
        if (_sent)
          TextButton(
            onPressed: _sending || form.submitting ? null : _send,
            child: const Text('Resend verification code'),
          ),
        if (_sent)
          TextButton(
            onPressed:
                form.submitting || _sending
                    ? null
                    : () => setState(() {
                      _sent = false;
                      _code.clear();
                      _failure = null;
                    }),
            child: const Text('Change email'),
          ),
      ],
    );
  }
}

class AccountCreatedScreen extends ConsumerStatefulWidget {
  const AccountCreatedScreen({super.key});

  @override
  ConsumerState<AccountCreatedScreen> createState() =>
      _AccountCreatedScreenState();
}

class _AccountCreatedScreenState extends ConsumerState<AccountCreatedScreen> {
  bool _continuing = false;

  Future<void> _continue() async {
    if (_continuing) return;
    setState(() => _continuing = true);
    await applyPendingOnboardingDraft(ref);
    if (mounted) context.go('/screen/permissions-intro');
  }

  @override
  Widget build(BuildContext context) => _ResultPage(
    icon: Icons.check_rounded,
    assetPath: 'assets/authentication/account_created.png',
    color: PelevoColors.red,
    eyebrow: 'Account Created',
    title: 'Welcome to Pelevo',
    body:
        "Your account has been created successfully.\nLet's personalize your experience.",
    button: _continuing ? 'Please wait…' : 'Start Exploring',
    onPressed: _continue,
  );
}

class SignInOptionsScreen extends StatelessWidget {
  const SignInOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) => _AuthPage(
    title: 'Sign in options',
    subtitle: 'Choose how you want to\nsign in to Pelevo',
    children: [
      _ProviderButton(
        'Continue with Email',
        Icons.email_outlined,
        PelevoColors.red,
      ),
      if (showsGoogleSignIn)
        _ProviderButton(
          'Continue with Google',
          Icons.g_mobiledata,
          PelevoColors.yellow,
        ),
      if (showsAppleSignIn)
        _ProviderButton('Continue with Apple', Icons.apple, PelevoColors.green),
      _ProviderButton(
        'Continue with Facebook',
        Icons.facebook,
        PelevoColors.blue,
      ),
      TextButton(
        onPressed: () => context.go('/screen/auth-sign-in'),
        child: const Text(
          'Back to sign in',
          style: TextStyle(color: PelevoColors.green),
        ),
      ),
    ],
  );
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthPage(
    back: true,
    title: 'Forgot Password',
    subtitle:
        "Enter your email and we'll send\nyou a code to reset your password.",
    children: [
      _Field(
        label: 'Email',
        hint: 'Enter your email address',
        icon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
        controller: _email,
        autofillHints: const [AutofillHints.email],
      ),
      PelevoButton(
        label: _submitting ? 'Sending…' : 'Send Reset Code',
        color: PelevoColors.yellow,
        foregroundColor: Colors.black,
        onPressed: _submitting ? null : _submit,
      ),
      TextButton(
        onPressed: () => context.go('/screen/auth-sign-in'),
        child: const Text(
          'Back to sign in',
          style: TextStyle(color: PelevoColors.green),
        ),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      const _AssetIllustration(
        assetPath: 'assets/authentication/forgot_password.png',
        semanticLabel: 'Password reset envelope and lock',
      ),
    ],
  );

  Future<void> _submit() async {
    if (!_email.text.contains('@')) {
      context.showPelevoMessage('Enter a valid email address');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(authRepositoryProvider).forgotPassword(_email.text);
      if (mounted) {
        context.go(
          Uri(
            path: '/screen/auth-check-email',
            queryParameters: {'email': _email.text.trim()},
          ).toString(),
        );
      }
    } catch (_) {
      if (mounted) {
        context.showPelevoMessage(
          'Unable to send the reset email. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class CheckEmailScreen extends ConsumerStatefulWidget {
  const CheckEmailScreen({super.key});
  @override
  ConsumerState<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends ConsumerState<CheckEmailScreen> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _complete = false;
  ApiFailure? _error;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _reset(String email) async {
    if (_busy) return;
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text) ||
        _password.text.isEmpty ||
        _password.text != _confirmation.text) {
      context.showPelevoMessage('Enter your code and matching passwords');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(
            email: email,
            code: _code.text,
            password: _password.text,
            confirmation: _confirmation.text,
          );
      await ref.read(authSessionProvider.notifier).clear();
      _code.clear();
      _password.clear();
      _confirmation.clear();
      if (mounted) setState(() => _complete = true);
    } on DioException catch (error) {
      if (mounted) setState(() => _error = apiFailureFromDio(error));
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = GoRouterState.of(context).uri.queryParameters['email'] ?? '';
    if (_complete) {
      return _ResultPage(
        icon: Icons.check_rounded,
        color: PelevoColors.green,
        title: 'Password updated',
        body: 'Sign in using your new password.',
        button: 'Back to sign in',
        onPressed: () => context.go('/screen/auth-sign-in'),
      );
    }
    return _AuthPage(
      back: true,
      title: 'Check your email',
      subtitle:
          email.isEmpty
              ? 'Request a reset code to continue.'
              : 'If an account exists for $email, a reset code will arrive shortly.',
      children: [
        const _AssetIllustration(
          assetPath: 'assets/authentication/check_email.png',
          semanticLabel: 'Password reset email',
        ),
        if (email.isNotEmpty) ...[
          _Field(
            label: 'Verification code',
            hint: '6-digit code',
            icon: Icons.lock_outline,
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
          ),
          _Field(
            label: 'New password',
            hint: 'Enter new password',
            icon: Icons.lock_outline,
            controller: _password,
            obscure: true,
            autofillHints: const [AutofillHints.newPassword],
          ),
          _Field(
            label: 'Confirm password',
            hint: 'Confirm new password',
            icon: Icons.lock_outline,
            controller: _confirmation,
            obscure: true,
          ),
          if (_error case final error?)
            _AuthError(error.message, requestId: error.requestId),
          PelevoButton(
            label: _busy ? 'Updating…' : 'Reset Password',
            onPressed: _busy ? null : () => _reset(email),
          ),
        ],
        TextButton(
          onPressed:
              _busy ? null : () => context.go('/screen/auth-forgot-password'),
          child: const Text('Request another code'),
        ),
      ],
    );
  }
}

class _AuthPage extends StatelessWidget {
  const _AuthPage({
    required this.title,
    required this.subtitle,
    required this.children,
    this.brand = false,
    this.back = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool brand;
  final bool back;

  @override
  Widget build(BuildContext context) => PelevoPage(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (back)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: () => context.go('/screen/auth-sign-in'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
            const SizedBox(height: PelevoSpacing.lg),
            if (brand) const _Brand(),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: PelevoSpacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PelevoColors.textMuted),
            ),
            const SizedBox(height: PelevoSpacing.xxl),
            ...children.expand(
              (child) => [child, const SizedBox(height: PelevoSpacing.md)],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.controller,
    this.autofillHints,
    this.enabled = true,
  });

  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Semantics(
    textField: true,
    label: label,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: PelevoSpacing.xxs),
        SizedBox(
          height: 48,
          child: TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscure,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, size: 19),
              suffixIcon: suffix,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: PelevoSpacing.sm,
                vertical: PelevoSpacing.sm,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _AuthError extends StatelessWidget {
  const _AuthError(this.message, {this.requestId});
  final String message;
  final String? requestId;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(PelevoSpacing.sm),
      decoration: BoxDecoration(
        color: PelevoColors.red.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(PelevoRadii.small),
      ),
      child: Text(
        requestId == null ? message : '$message\nReference: $requestId',
        style: const TextStyle(color: PelevoColors.red),
      ),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: PelevoSpacing.xl),
    child: Semantics(
      image: true,
      label: 'Pelevo',
      child: Image.asset(
        'assets/authentication/auth_brand.png',
        width: 132,
        height: 136,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    ),
  );
}

class _AssetIllustration extends StatelessWidget {
  const _AssetIllustration({
    required this.assetPath,
    required this.semanticLabel,
  });

  final String assetPath;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    child: Image.asset(
      assetPath,
      width: 132,
      height: 150,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    ),
  );
}

class _ProviderButton extends ConsumerWidget {
  const _ProviderButton(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(bottom: PelevoSpacing.sm),
    child: PelevoButton(
      label: label,
      icon: icon,
      outlined: true,
      color: color,
      foregroundColor: PelevoColors.text,
      onPressed:
          ref.watch(authFormProvider).submitting
              ? null
              : () async {
                if (label.contains('Email')) {
                  context.go('/screen/auth-sign-in');
                  return;
                }
                await _continueWithSocial(context, ref, label);
              },
    ),
  );
}

class _SocialButton extends ConsumerWidget {
  const _SocialButton(this.label, this.icon);

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    button: true,
    label: 'Continue with $label',
    child: IconButton.filledTonal(
      tooltip: label,
      onPressed:
          ref.watch(authFormProvider).submitting
              ? null
              : () => _continueWithSocial(context, ref, label),
      icon: Icon(icon),
    ),
  );
}

Future<void> _continueWithSocial(
  BuildContext context,
  WidgetRef ref,
  String label,
) async {
  final provider = label.toLowerCase().contains('google')
      ? 'google'
      : label.toLowerCase().contains('apple')
      ? 'apple'
      : null;
  if (provider == null) {
    _showProviderUnavailable(context, label);
    return;
  }
  try {
    final tokens = provider == 'google'
        ? await SocialAuthService.google()
        : await SocialAuthService.apple();
    final success = await ref
        .read(authFormProvider.notifier)
        .social(
          provider: tokens.provider,
          token: tokens.token,
          nonce: tokens.nonce,
        );
    if (!context.mounted) return;
    if (!success) {
      final failure = ref.read(authFormProvider).failure;
      context.showPelevoMessage(
        failure?.message ?? '$label sign-in failed.',
      );
      return;
    }
    await applyPendingOnboardingDraft(ref);
    if (!context.mounted) return;
    context.go('/screen/home-feed');
  } on ApiFailure catch (failure) {
    if (context.mounted) context.showPelevoMessage(failure.message);
  } on SignInWithAppleAuthorizationException catch (error) {
    if (error.code == AuthorizationErrorCode.canceled || !context.mounted) {
      return;
    }
    context.showPelevoMessage('Sign in with Apple failed.');
  } on GoogleSignInException catch (error) {
    if (!context.mounted) return;
    final description = error.description?.trim() ?? '';
    final userCanceled =
        error.code == GoogleSignInExceptionCode.canceled &&
        (description.isEmpty ||
            description.toLowerCase().contains('cancel'));
    if (userCanceled) return;
    context.showPelevoMessage(
      description.isEmpty ? 'Google Sign-In failed.' : description,
    );
  } on Object catch (error) {
    if (context.mounted) {
      context.showPelevoMessage('$label sign-in failed: $error');
    }
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: PelevoSpacing.sm),
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
      const Expanded(child: Divider()),
    ],
  );
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.prefix,
    required this.action,
    required this.onTap,
  });

  final String prefix;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    child: Text.rich(
      TextSpan(
        text: prefix,
        style: const TextStyle(color: PelevoColors.textMuted),
        children: [
          TextSpan(
            text: action,
            style: const TextStyle(color: PelevoColors.green),
          ),
        ],
      ),
    ),
  );
}

class _AuthIllustration extends StatelessWidget {
  const _AuthIllustration({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: .2), blurRadius: 28),
        ],
      ),
      child: Icon(icon, size: 64, color: color),
    ),
  );
}

class _ResultPage extends StatelessWidget {
  const _ResultPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.button,
    required this.onPressed,
    this.eyebrow,
    this.assetPath,
  });

  final IconData icon;
  final String? assetPath;
  final Color color;
  final String? eyebrow;
  final String title;
  final String body;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => PelevoPage(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          children: [
            const SizedBox(height: 54),
            if (assetPath == null)
              _AuthIllustration(icon: icon, color: color)
            else
              _AssetIllustration(assetPath: assetPath!, semanticLabel: title),
            const SizedBox(height: PelevoSpacing.xxl),
            if (eyebrow != null) ...[
              Text(
                eyebrow!,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: PelevoSpacing.sm),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: PelevoSpacing.md),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PelevoColors.textMuted),
            ),
            const SizedBox(height: PelevoSpacing.xxl),
            PelevoButton(label: button, color: color, onPressed: onPressed),
          ],
        ),
      ),
    ),
  );
}

void _showProviderUnavailable(BuildContext context, String provider) {
  showDialog<void>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Sign-in option unavailable'),
          content: Text(
            '$provider sign-in is not available in this build. Please use email.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Continue with email'),
            ),
          ],
        ),
  );
}
