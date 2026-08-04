import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';

/// The nine preset avatars shipped under `assets/user_profiles/`. The
/// filename is what gets stored in `users.profile_icon` for preset picks.
const List<String> kPresetAvatars = [
  'buddy_buggy.png',
  'camper.png',
  'chill_buddy.png',
  'chill_wheels.png',
  'lone_rider.png',
  'peepers.png',
  'smooth_operator.png',
  'solo_driver.png',
  'the_roadtripper.png',
];

/// Bottom sheet for changing the profile picture: choose one of the preset
/// "moods" (Waze convention) or upload a photo from the device library.
/// Custom uploads are cropped to a circle before being sent to Cloudinary.
class ProfilePictureSheet extends StatelessWidget {
  const ProfilePictureSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ProfilePictureSheet(),
    );
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    debugPrint('📸 [UPLOAD] Step 1: opening image picker');
    final picker = ImagePicker();
    XFile? picked;
    try {
      // Aggressive downscale + compression at pick time so we don't waste
      // memory on a 10 MP camera JPEG for something we'll display at 60px.
      // 800px longest edge is more than enough for a profile pic.
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
    } catch (e) {
      debugPrint('📸 [UPLOAD] ❌ picker.pickImage threw: $e');
      return;
    }
    if (picked == null) {
      debugPrint('📸 [UPLOAD] user cancelled picker (picked == null)');
      return;
    }
    if (!context.mounted) {
      debugPrint('📸 [UPLOAD] ❌ context unmounted after picker');
      return;
    }
    debugPrint('📸 [UPLOAD] Step 2: picked file ${picked.path} '
        '(size ~${await File(picked.path).length()} bytes)');

    // Crop to a 1:1 circle. Force max 512×512 output so a giant square
    // crop can't blow past the upload cap — a profile picture is going
    // to be displayed at 60-200px on device anyway.
    debugPrint('📸 [UPLOAD] Step 3: opening cropper');
    CroppedFile? cropped;
    try {
      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 512,
        maxHeight: 512,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 70, // 70% JPEG — visually indistinguishable at avatar size
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop profile picture',
            toolbarColor: const Color(0xFFFF0000),
            toolbarWidgetColor: Colors.white,
            cropStyle: CropStyle.circle,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop profile picture',
            aspectRatioLockEnabled: true,
          ),
        ],
      );
    } catch (e, st) {
      debugPrint('📸 [UPLOAD] ❌ cropImage threw: $e');
      debugPrint('$st');
      return;
    }
    if (cropped == null) {
      debugPrint('📸 [UPLOAD] user cancelled cropper (cropped == null)');
      return;
    }
    if (!context.mounted) {
      debugPrint('📸 [UPLOAD] ❌ context unmounted after cropper');
      return;
    }
    final croppedFile = File(cropped.path);
    final finalSize = await croppedFile.length();
    debugPrint('📸 [UPLOAD] Step 4: cropped to ${cropped.path} '
        '(size ~${finalSize} bytes = ${(finalSize / 1024).toStringAsFixed(1)} KB)');

    debugPrint('📸 [UPLOAD] Step 5: dispatching ProfilePictureUploadRequested');
    context.read<AuthBloc>().add(
          AuthEvent.profilePictureUploadRequested(image: croppedFile),
        );
    debugPrint('📸 [UPLOAD] Step 6: closing picker sheet');
    if (context.mounted) Navigator.of(context).pop();
  }

  void _selectPreset(BuildContext context, String filename) {
    // Preset avatars are stored by filename; the display layer already
    // knows to load them from `assets/user_profiles/` when the value
    // doesn't look like a URL.
    context.read<AuthBloc>().add(
          AuthEvent.updateProfileRequested(profileIcon: filename),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Change profile picture',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick a mood or upload your own',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          // "Upload photo" row
          _UploadRow(onTap: () => _pickAndUpload(context)),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          // Preset avatar grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final asset in kPresetAvatars)
                _PresetTile(
                  asset: asset,
                  onTap: () => _selectPreset(context, asset),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadRow extends StatelessWidget {
  const _UploadRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFCCCC)),
        ),
        child: Row(
          children: [
            const Icon(Icons.photo_camera, color: Color(0xFFFF0000)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload from library',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Pick a photo and crop to a circle',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.asset, required this.onTap});
  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(60),
      child: ClipOval(
        child: Image.asset(
          'assets/user_profiles/$asset',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
