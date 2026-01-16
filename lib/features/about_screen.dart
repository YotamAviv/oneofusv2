import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  final VoidCallback onDevClick;

  const AboutScreen({super.key, required this.onDevClick});

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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Color(0xFF37474F),
                  ),
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
                  onTap: onDevClick,
                  child: const Center(
                    child: Column(
                      children: [
                        Text(
                          'With ♡ from Clacker;)',
                          style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 0.5),
                        ),
                        SizedBox(height: 8),
                        Text('V2.0.0 • BUILD 80', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey.shade300,
          letterSpacing: 2.0,
        ),
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
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF37474F))),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600)) : null,
      trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.grey),
      onTap: () => launchUrl(Uri.parse(url)),
    );
  }
}
