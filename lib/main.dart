import 'package:flutter/material.dart';

void main() {
  runApp(const EcoflowApp());
}

class EcoflowApp extends StatelessWidget {
  const EcoflowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ecoflow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C27A),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const EcoflowDashboardPage(),
    );
  }
}

enum _DashboardTab {
  home,
  createAd,
  dashboard,
}

class EcoflowDashboardPage extends StatefulWidget {
  const EcoflowDashboardPage({super.key});

  @override
  State<EcoflowDashboardPage> createState() => _EcoflowDashboardPageState();
}

class _EcoflowDashboardPageState extends State<EcoflowDashboardPage> {
  _DashboardTab _currentTab = _DashboardTab.home;

  void _goTo(_DashboardTab tab) {
    setState(() {
      _currentTab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FFFB),
      body: SafeArea(
        child: Column(
          children: [
            _TopNavigationBar(
              selectedTab: _currentTab,
              onHomeTap: () => _goTo(_DashboardTab.home),
              onCreateAdTap: () => _goTo(_DashboardTab.createAd),
              onDashboardTap: () => _goTo(_DashboardTab.dashboard),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 32,
                      ),
                      child: _buildContent(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentTab) {
      case _DashboardTab.home:
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 40,
              ),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.8, -0.3),
                  radius: 1.4,
                  colors: [
                    const Color(0xCCDFFEF1),
                    Colors.white.withOpacity(0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: _HeroSection(
                onCreateAdTap: () => _goTo(_DashboardTab.createAd),
              ),
            ),
            const SizedBox(height: 80),
            const _FeaturesSection(),
            const SizedBox(height: 40),
          ],
        );
      case _DashboardTab.createAd:
        return const _CreateAdSection();
      case _DashboardTab.dashboard:
        return const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            'Tableau de bord à venir…',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4B5563),
            ),
          ),
        );
    }
  }
}

class _TopNavigationBar extends StatelessWidget {
  final _DashboardTab selectedTab;
  final VoidCallback onHomeTap;
  final VoidCallback onCreateAdTap;
  final VoidCallback onDashboardTap;

  const _TopNavigationBar({
    required this.selectedTab,
    required this.onHomeTap,
    required this.onCreateAdTap,
    required this.onDashboardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF00C27A),
                      Color(0xFF00BFA5),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.loop,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Ecoflow',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF007F5F),
                ),
              ),
            ],
          ),
          Row(
            children: [
              _NavItem(
                label: 'Accueil',
                isSelected: selectedTab == _DashboardTab.home,
                onTap: onHomeTap,
              ),
              const SizedBox(width: 24),
              _NavItem(
                label: 'Créer une annonce',
                icon: Icons.add,
                isSelected: selectedTab == _DashboardTab.createAd,
                onTap: onCreateAdTap,
              ),
              const SizedBox(width: 24),
              _NavItem(
                label: 'Tableau de bord',
                icon: Icons.location_on_outlined,
                isSelected: selectedTab == _DashboardTab.dashboard,
                onTap: onDashboardTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isSelected ? const Color(0xFF00A86B) : const Color(0xFF374151);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0FFE9) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: textColor,
                size: 20,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final VoidCallback onCreateAdTap;

  const _HeroSection({
    required this.onCreateAdTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE0FFE9),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.eco_outlined,
                size: 18,
                color: Color(0xFF00A86B),
              ),
              SizedBox(width: 8),
              Text(
                'Plateforme intelligente de recyclage',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF047857),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Connectez-vous pour un recyclage plus efficace',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 24),
        const SizedBox(
          width: 700,
          child: Text(
            'Une plateforme qui connecte les particuliers, les commerces et les '
            '"barbèches" (récupérateurs informels) pour optimiser la collecte '
            'des matériaux de valeur (carton, plastique, métal).',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Color(0xFF4B5563),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PrimaryActionButton(
              label: 'Créer une annonce',
              icon: Icons.arrow_right_alt,
              onPressed: onCreateAdTap,
            ),
            const SizedBox(width: 20),
            _SecondaryActionButton(
              label: 'En savoir plus',
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE0FFE9),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.auto_awesome_outlined,
                size: 18,
                color: Color(0xFF00A86B),
              ),
              SizedBox(width: 8),
              Text(
                'Fonctionnalités clés avec l\'IA',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF047857),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Une innovation pour la Tunisie',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(
          width: 800,
          child: Text(
            'Digitalise et valorise un maillon essentiel mais informel de la chaîne '
            'de recyclage, le rendant plus efficace et transparent.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Color(0xFF4B5563),
            ),
          ),
        ),
        const SizedBox(height: 48),
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 700;

            final cards = <Widget>[
              Expanded(
                child: _FeatureCard(
                  icon: Icons.photo_camera_outlined,
                  iconGradient: const LinearGradient(
                    colors: [
                      Color(0xFF007CF0),
                      Color(0xFF00DFD8),
                    ],
                  ),
                  title: 'Annonce Intelligente',
                  description:
                      'Prenez en photo vos matériaux. L\'IA estime automatiquement '
                      'le volume, le poids et la valeur marchande approximative.',
                ),
              ),
              const SizedBox(width: 32, height: 32),
              Expanded(
                child: _FeatureCard(
                  icon: Icons.group_outlined,
                  iconGradient: const LinearGradient(
                    colors: [
                      Color(0xFF00C27A),
                      Color(0xFF00BFA5),
                    ],
                  ),
                  title: 'Système de Matching',
                  description:
                      'L\'IA notifie automatiquement les collecteurs inscrits à '
                      'proximité, en fonction du type de matériau.',
                ),
              ),
            ];

            if (isSmall) {
              return Column(children: cards);
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: cards,
            );
          },
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final LinearGradient iconGradient;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: iconGradient,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Color(0xFF4B5563),
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

class _CreateAdSection extends StatelessWidget {
  const _CreateAdSection();

  InputDecoration _fieldDecoration({
    String? hintText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hintText,
      prefixIcon: prefixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFFD1D5DB),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFFD1D5DB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFF00C27A),
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Créer une annonce',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Prenez en photo vos matériaux et notre IA les analysera automatiquement',
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Photo des matériaux',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFD1D5DB),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.photo_camera_outlined,
                          size: 40,
                          color: Color(0xFF9CA3AF),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Cliquez pour prendre ou télécharger une photo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'PNG, JPG jusqu\'à 10MB',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Type de matériau',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: _fieldDecoration(
                    hintText: 'Sélectionnez un type',
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: const [
                    DropdownMenuItem(
                      value: 'Carton',
                      child: Text('Carton'),
                    ),
                    DropdownMenuItem(
                      value: 'Plastique',
                      child: Text('Plastique'),
                    ),
                    DropdownMenuItem(
                      value: 'Métal',
                      child: Text('Métal'),
                    ),
                    DropdownMenuItem(
                      value: 'Verre',
                      child: Text('Verre'),
                    ),
                  ],
                  onChanged: (_) {},
                ),
                const SizedBox(height: 24),
                const Text(
                  'Localisation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: _fieldDecoration(
                    hintText: 'Ex: Tunis, Ariana, Sfax...',
                    prefixIcon: const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Description (optionnelle)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 4,
                  decoration: _fieldDecoration(
                    hintText: 'Ajoutez des détails supplémentaires...',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF00C27A),
                  Color(0xFF00BFA5),
                ],
              ),
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Publier l\'annonce',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF00C27A),
            Color(0xFF00BFA5),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryActionButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(
          color: Color(0xFF7FE3B5),
          width: 2,
        ),
        foregroundColor: const Color(0xFF047857),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

