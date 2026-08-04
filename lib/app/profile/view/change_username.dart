import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/models/auth/auth_response.dart';

/// Waze-style once-only username change. Prefilled with the current handle;
/// backend rejects with 403 if the user has already used their one change,
/// or 409 if the new handle is taken. UI blocks submission if the local
/// [User.canChangeUsername] is false so the user sees the lock immediately
/// rather than after a round-trip.
class ChangeUsernameScreen extends StatefulWidget {
  const ChangeUsernameScreen({super.key});

  @override
  State<ChangeUsernameScreen> createState() => _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends State<ChangeUsernameScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _serverError;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthSuccess && auth.user?.username != null) {
      _controller.text = auth.user!.username!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _localValidate(String? value) {
    final v = (value ?? '').trim();
    if (v.length < 3) return 'At least 3 characters';
    if (v.length > 20) return 'At most 20 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
      return 'Only letters, numbers, and underscore';
    }
    return null;
  }

  Future<void> _confirmAndSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final newUsername = _controller.text.trim();

    // This is a one-way door — Waze convention. Force a confirmation so it's
    // not a surprise.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Change username?'),
        content: Text(
          "You can only change your username once. After this, '$newUsername' will be your permanent handle.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF0000),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Yes, change it'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _serverError = null);
    context.read<AuthBloc>().add(
          AuthEvent.usernameChangeRequested(newUsername: newUsername),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (prev, next) =>
          next is ProfileUpdateFailed ||
          (next is AuthSuccess && prev is ProfileUpdating),
      listener: (context, state) {
        if (state is ProfileUpdateFailed) {
          setState(() => _serverError = state.message);
        } else if (state is AuthSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username updated')),
          );
          if (context.canPop()) context.pop();
        }
      },
      builder: (context, state) {
        final isSaving = state is ProfileUpdating;
        final authUser =
            state is AuthSuccess ? state.user : _findUserInAnyState();
        final canChange = authUser?.canChangeUsername ?? true;

        return Column(
          children: [
            AppHeader(
              backIcon: Assets.icons.backArrow,
              isTransparent: true,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: styles.insets.md),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Gap(16 * styles.scale),
                      Text(
                        'Change username',
                        style: styles.typography.h3.textColor(styles.theme.text),
                      ),
                      Gap(8 * styles.scale),
                      Text(
                        'Your username is how others in the community see you '
                        'on reports, comments, and chat.',
                        style: styles.typography.body
                            .textColor(styles.theme.ash),
                      ),
                      Gap(20 * styles.scale),
                      if (!canChange) _buildLockedWarning(),
                      if (!canChange) Gap(16 * styles.scale),
                      Text(
                        'Username',
                        style: styles.typography.body
                            .textColor(styles.theme.text),
                      ),
                      Gap(2 * styles.scale),
                      TextFormField(
                        controller: _controller,
                        enabled: canChange && !isSaving,
                        maxLength: 20,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9_]')),
                        ],
                        decoration: InputDecoration(
                          hintText: 'e.g. LagosDriver_42',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: styles.theme.white,
                          errorText: _serverError,
                        ),
                        validator: _localValidate,
                      ),
                      Gap(8 * styles.scale),
                      Text(
                        canChange
                            ? '⚠︎ You can only change your username once.'
                            : 'Contact support if you need to change it again.',
                        style: styles.typography.caption.textColor(
                          canChange ? Colors.orange.shade800 : styles.theme.ash,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              height: 80,
              padding: EdgeInsets.symmetric(horizontal: styles.insets.md),
              child: AppBtn.from(
                onPressed:
                    (isSaving || !canChange) ? null : _confirmAndSubmit,
                semanticLabel: 'change-username',
                expand: true,
                corner: styles.corners.x24,
                text: isSaving ? 'Saving…' : 'Save',
                iconColor: styles.theme.primary,
                bgColor: styles.theme.secondary,
                padding: EdgeInsets.symmetric(vertical: styles.insets.xs),
                minimumSize: const Size(0, 56),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLockedWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.orange),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'You have already changed your username once. '
              'It cannot be changed again from the app.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Fallback: if the bloc is briefly in [ProfileUpdating] we can't get the
  /// user from the state, so peek at the most recent AuthSuccess we've seen.
  User? _findUserInAnyState() {
    // We don't have a proper history here, so just return null — the button
    // stays disabled during [ProfileUpdating] anyway.
    return null;
  }
}
