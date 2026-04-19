import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:cumobile/core/theme/app_colors.dart';
import 'package:cumobile/data/models/student_lms_profile.dart';
import 'package:cumobile/data/models/student_profile.dart';

class HomeTopNavigation extends StatelessWidget {
  final String title;
  final StudentLmsProfile? lmsProfile;
  final StudentProfile? profile;
  final Uint8List? avatarBytes;
  final bool isLoadingProfile;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;

  const HomeTopNavigation({
    super.key,
    required this.title,
    required this.lmsProfile,
    required this.profile,
    this.avatarBytes,
    required this.isLoadingProfile,
    required this.onOpenNotifications,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),
          ),
          if (lmsProfile != null) ...[
            Text(
              'Late Days: ${lmsProfile!.lateDaysBalance}',
              style: TextStyle(fontSize: 12, color: c.textTertiary),
            ),
            const SizedBox(width: 12),
          ],
          if (isIos)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onOpenNotifications,
              child: Icon(CupertinoIcons.bell, color: c.textPrimary),
            )
          else
            IconButton(
              onPressed: onOpenNotifications,
              icon: Icon(Icons.notifications_none, color: c.textPrimary),
              tooltip: 'Уведомления',
            ),
          GestureDetector(
            onTap: onOpenProfile,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: profile != null
                    ? c.accent.withValues(alpha: 0.2)
                    : c.surface,
                border: Border.all(color: c.accent, width: 2),
              ),
              child: isLoadingProfile
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: isIos
                          ? CupertinoActivityIndicator(
                              radius: 8,
                              color: c.accent,
                            )
                          : CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.accent,
                            ),
                    )
                  : avatarBytes != null
                      ? ClipOval(
                          child: Image.memory(
                            avatarBytes!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: profile != null
                              ? Text(
                                  '${profile!.firstName[0]}${profile!.lastName[0]}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: c.accent,
                                  ),
                                )
                              : Icon(
                                  isIos ? CupertinoIcons.person : Icons.person,
                                  color: c.textTertiary,
                                  size: 20,
                                ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
