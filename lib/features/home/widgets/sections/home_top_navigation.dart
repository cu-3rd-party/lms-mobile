import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          if (lmsProfile != null) ...[
            Text(
              'Late Days: ${lmsProfile!.lateDaysBalance}',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
            const SizedBox(width: 12),
          ],
          if (isIos)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onOpenNotifications,
              child: const Icon(CupertinoIcons.bell, color: Colors.white),
            )
          else
            IconButton(
              onPressed: onOpenNotifications,
              icon: const Icon(Icons.notifications_none, color: Colors.white),
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
                    ? const Color(0xFF00E676).withValues(alpha: 0.2)
                    : const Color(0xFF1E1E1E),
                border: Border.all(color: const Color(0xFF00E676), width: 2),
              ),
              child: isLoadingProfile
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: isIos
                          ? const CupertinoActivityIndicator(
                              radius: 8,
                              color: Color(0xFF00E676),
                            )
                          : const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00E676),
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
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00E676),
                                  ),
                                )
                              : Icon(
                                  isIos ? CupertinoIcons.person : Icons.person,
                                  color: Colors.grey[500],
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
