import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/repositories/auth_repository.dart';

class UpdateUsernameScreen extends StatefulWidget {
  const UpdateUsernameScreen({super.key});

  @override
  State<UpdateUsernameScreen> createState() => _UpdateUsernameScreenState();
}

class _UpdateUsernameScreenState extends State<UpdateUsernameScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _saving = false;
  bool _hasPrefilled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fillFromUser();
      // Subscribe to bloc so we catch AuthSuccess if it arrives after the screen opens
      context.read<AuthBloc>().stream.listen((state) {
        if (!_hasPrefilled && state is AuthSuccess) _fillFromUser();
      });
    });
  }

  void _fillFromUser() {
    if (_hasPrefilled) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess || authState.user == null) return;

    _hasPrefilled = true;
    final user = authState.user!;
    _firstNameController.text = user.firstName?.trim() ?? '';
    _lastNameController.text = user.lastName?.trim() ?? '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    if (first.isEmpty && last.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter at least first or last name')),
        );
      }
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AuthRepository>().updateProfile(
            firstname: first.isEmpty ? null : first,
            lastname: last.isEmpty ? null : last,
          );
      if (!mounted) return;
      context.read<AuthBloc>().add(const GetProfileRequested());
      if (!mounted) return;
      context.pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Gap(16 * styles.scale),
                Text(
                  'Update your name',
                  style: styles.typography.h3.textColor(styles.theme.text),
                ),
                Gap(8 * styles.scale),
                Text(
                  'What do you want us to call you by? Enter your full name below',
                  style: styles.typography.body.textColor(styles.theme.ash),
                ),
                Gap(24 * styles.scale),
                Text(
                  'First name',
                  style: styles.typography.body.textColor(styles.theme.text),
                ),
                Gap(2 * styles.scale),
                CustomTextField(
                  controller: _firstNameController,
                  fillColor: styles.theme.white,
                  hintText: 'Enter your first name',
                  prefix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconBtn(
                        icon: Assets.icons.profile,
                        bgColor: Colors.transparent,
                        color: styles.theme.text,
                        onPressed: () {},
                        semanticLabel: 'first-name',
                      ),
                      Text(
                        '|',
                        style: styles.typography.h4.textColor(styles.theme.ash),
                      ),
                    ],
                  ),
                ),
                Gap(16 * styles.scale),
                Text(
                  'Last name',
                  style: styles.typography.body.textColor(styles.theme.text),
                ),
                Gap(2 * styles.scale),
                CustomTextField(
                  controller: _lastNameController,
                  fillColor: styles.theme.white,
                  hintText: 'Enter your last name',
                  prefix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconBtn(
                        icon: Assets.icons.profile,
                        bgColor: Colors.transparent,
                        color: styles.theme.text,
                        onPressed: () {},
                        semanticLabel: 'last-name',
                      ),
                      Text(
                        '|',
                        style: styles.typography.h4.textColor(styles.theme.ash),
                      ),
                    ],
                  ),
                ),
                Gap(48 * styles.scale),
              ],
            ),
          ),
        ),
        Container(
          height: 80,
          padding: EdgeInsets.symmetric(horizontal: styles.insets.md),
          child: Column(
            children: [
              AppBtn.from(
                onPressed: _saving ? null : _save,
                semanticLabel: 'save-profile',
                expand: true,
                corner: styles.corners.x24,
                text: _saving ? 'Saving…' : 'Save',
                iconColor: styles.theme.primary,
                bgColor: styles.theme.secondary,
                padding: EdgeInsets.symmetric(vertical: styles.insets.xs),
                minimumSize: const Size(0, 56),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
