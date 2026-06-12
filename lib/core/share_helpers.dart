import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:ui' as ui;

/// WhatsApp-first sharing — in the Indian market WhatsApp IS the channel.
/// Falls back to the native share sheet when WhatsApp isn't installed.
Future<void> shareViaWhatsApp(String text) async {
  final wa = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
  if (await canLaunchUrl(wa)) {
    await launchUrl(wa, mode: LaunchMode.externalApplication);
    return;
  }
  final waWeb = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
  if (await canLaunchUrl(waWeb)) {
    await launchUrl(waWeb, mode: LaunchMode.externalApplication);
    return;
  }
  await SharePlus.instance.share(ShareParams(text: text));
}

/// Generic share sheet.
Future<void> shareText(String text, {String? subject}) =>
    SharePlus.instance.share(ShareParams(text: text, subject: subject));

/// Capture a [RepaintBoundary] (by key) as a PNG and open the share sheet —
/// powers Wrapped cards and badge brags.
Future<void> shareWidgetAsImage(
  GlobalKey boundaryKey, {
  String filename = 'the-wall.png',
  String? text,
}) async {
  final boundary = boundaryKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
  if (boundary == null) return;
  final image = await boundary.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return;
  final bytes = byteData.buffer.asUint8List();

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);

  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'image/png', bytes: Uint8List.fromList(bytes))],
    text: text,
  ));
}
