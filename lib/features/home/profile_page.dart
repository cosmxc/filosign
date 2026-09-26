import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final profileName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : 'FSL Learner';

    return _buildSecondaryPage(
      icon: Icons.person_rounded,
      title: 'Profile',
      child: Column(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: const Color(0xFFFFE1C8),
            child: Text(
              profileName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFC45E22),
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            profileName,
            style: const TextStyle(
              color: Color(0xFF153B39),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            user?.email ?? '',
            style: const TextStyle(color: Color(0xFF6B8581)),
          ),
          const SizedBox(height: 30),
          _buildInfoTile(
            Icons.local_fire_department_outlined,
            'Current streak',
            '3 days',
          ),
          _buildInfoTile(
            Icons.school_outlined,
            'Lessons completed',
            '0 lessons',
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryPage({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF087F73), size: 27),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF153B39),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EEEB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF087F73)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF153B39),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(value, style: const TextStyle(color: Color(0xFF6B8581))),
        ],
      ),
    );
  }
}