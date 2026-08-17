import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants.dart';

class AppDialog {
  static Future<T?> show<T>(BuildContext context, {
    required String title,
    required String content,
    String? primaryButtonText,
    VoidCallback? onPrimaryButton,
    String? secondaryButtonText,
    VoidCallback? onSecondaryButton,
  }) {
    return showDialog<T>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(AppConstants.cardDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(AppConstants.borderColor)),
          ),
          title: Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            content,
            style: GoogleFonts.inter(
              color: Colors.grey[300],
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: <Widget>[
            if (secondaryButtonText != null)
              TextButton(
                onPressed: onSecondaryButton ?? () => Navigator.of(context).pop(),
                child: Text(
                  secondaryButtonText,
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (primaryButtonText != null)
              ElevatedButton(
                onPressed: onPrimaryButton ?? () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppConstants.neonAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text(
                  primaryButtonText,
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}