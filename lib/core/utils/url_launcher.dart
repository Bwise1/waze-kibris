import 'dart:ui';

import 'package:url_launcher/url_launcher.dart';

class UrlLauncher {
  const UrlLauncher._();

  static Future<void> launch(
    String url, {
    bool forceWebView = false,
    VoidCallback? callback,
  }) async {
    if (url.isNotEmpty == true) {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(
          Uri.parse(url),
          mode: forceWebView
              ? LaunchMode.platformDefault
              : LaunchMode.externalApplication,
        );
        if (callback != null) {
          callback();
        }
      } else {
        throw Exception('Could not launch $url');
      }
    }
  }

  static Future<void> call(String number) async {
    if (number.isNotEmpty == true) {
      final fixedNumber = number.replaceAll(RegExp('[^0-9|+]'), '');
      final tel = Uri(
        scheme: 'tel',
        path: fixedNumber,
      );

      if (await canLaunchUrl(tel)) {
        await launchUrl(tel);
      } else {
        throw Exception('Could not launch $tel');
      }
    }
  }

  static Future<void> sendEmail(String emailAddress) async {
    var url = 'mailto:$emailAddress';

    url = Uri.encodeFull(url);
    final parsedUrl = Uri.parse(url);

    if (await canLaunchUrl(parsedUrl)) {
      await launchUrl(parsedUrl);
    } else {
      throw Exception('Could not launch $parsedUrl');
    }
  }
}
