import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ui/app_typography.dart';

class AboutScreen extends StatefulWidget {
  final VoidCallback onDevClick;

  const AboutScreen({super.key, required this.onDevClick});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = "";
  
  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((packageInfo) {
      if (mounted) {
        setState(() {
          _version = 'V${packageInfo.version} • BUILD ${packageInfo.buildNumber}';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                Text(
                  'ONE-OF-US.NET',
                  style: AppTypography.header,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              children: [
                const _InfoCategory(title: 'RESOURCES'),
                _InfoLinkTile(
                  icon: Icons.home_outlined, 
                  title: 'Home', 
                  subtitle: 'https://one-of-us.net', 
                  url: 'https://one-of-us.net'
                ),
                _InfoLinkTile(
                  icon: Icons.menu_book_outlined, 
                  title: 'Manual', 
                  subtitle: 'Guides and documentation', 
                  url: 'https://one-of-us.net/man.html'
                ),
                
                const SizedBox(height: 24),
                const _InfoCategory(title: 'LEGAL & PRIVACY'),
                _InfoLinkTile(
                  icon: Icons.privacy_tip_outlined, 
                  title: 'Privacy Policy', 
                  url: 'https://one-of-us.net/policy.html'
                ),
                _InfoLinkTile(
                  icon: Icons.gavel_outlined, 
                  title: 'Terms & Conditions', 
                  url: 'https://one-of-us.net/terms.html'
                ),

                const SizedBox(height: 24),
                const _InfoCategory(title: 'SUPPORT'),
                _InfoLinkTile(
                  icon: Icons.email_outlined, 
                  title: 'Contact Support', 
                  subtitle: 'contact@one-of-us.net', 
                  url: 'mailto:contact@one-of-us.net'
                ),
                _InfoLinkTile(
                  icon: Icons.report_problem_outlined, 
                  title: 'Report Abuse', 
                  subtitle: 'abuse@one-of-us.net', 
                  url: 'mailto:abuse@one-of-us.net'
                ),
                
                const SizedBox(height: 60),
                GestureDetector(
                  onTap: widget.onDevClick,
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          'With ♡ from Clacker;)',
                          style: AppTypography.caption,
                        ),
                        const SizedBox(height: 8),
                        Text(_version, textAlign: TextAlign.center, style: AppTypography.labelSmall),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    ),
        ],
      ),
    );
  }
}

class _InfoCategory extends StatelessWidget {
  final String title;
  const _InfoCategory({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: AppTypography.label,
      ),
    );
  }
}

class _InfoLinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String url;

  const _InfoLinkTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF00897B)),
      title: Text(title, style: AppTypography.body),
      subtitle: subtitle != null ? Text(subtitle!, style: AppTypography.caption) : null,
      trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.grey),
      onTap: () => launchUrl(Uri.parse(url)),
    );
  }
}
