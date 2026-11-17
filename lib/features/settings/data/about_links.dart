import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final privacyPolicyUrl = Uri.parse('https://animosaic.app/privacy');
final termsOfUseUrl = Uri.parse('https://animosaic.app/terms');
const contactEmail = 'pirate.dmitry@gmail.com';
final contactEmailUrl = Uri(scheme: 'mailto', path: contactEmail);

/// Opens a link outside the app; replaced in tests.
final externalLinkLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);
