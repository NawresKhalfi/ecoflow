import 'package:flutter/material.dart';

/// Tableau de bord du collecteur pour Ecoflow.
class CollectorDashboard extends StatefulWidget {
  const CollectorDashboard({super.key});

  @override
  State<CollectorDashboard> createState() => _CollectorDashboardState();
}

enum _CollectorSection {
  availableAds,
  optimizedRoute,
  profile,
}

class _CollectorDashboardState extends State<CollectorDashboard> {
  _CollectorSection _section = _CollectorSection.availableAds;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFEFFDF7),
            borderRadius: BorderRadius.circular(32),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tableau de bord collecteur',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Gérez vos collectes et optimisez vos tournées',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 28),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _DashboardChip(
                      icon: Icons.list_alt_outlined,
                      label: 'Annonces disponibles',
                      isSelected:
                          _section == _CollectorSection.availableAds,
                      onTap: () {
                        setState(() {
                          _section = _CollectorSection.availableAds;
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                    _DashboardChip(
                      icon: Icons.map_outlined,
                      label: 'Tournée optimisée',
                      isSelected:
                          _section == _CollectorSection.optimizedRoute,
                      onTap: () {
                        setState(() {
                          _section = _CollectorSection.optimizedRoute;
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                    _DashboardChip(
                      icon: Icons.person_outline,
                      label: 'Mon profil',
                      isSelected: _section == _CollectorSection.profile,
                      onTap: () {
                        setState(() {
                          _section = _CollectorSection.profile;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _StatsRow(section: _section),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _FilterAndList(section: _section),
      ],
    );
  }
}

class _DashboardChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DashboardChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = isSelected ? const Color(0xFF00C27A) : Colors.white;
    final foreground =
        isSelected ? Colors.white : const Color(0xFF374151);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x2600C27A),
                    blurRadius: 14,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: foreground,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w500,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final _CollectorSection section;

  const _StatsRow({required this.section});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatCard(
        label: 'Annonces disponibles',
        value: '4',
      ),
      const SizedBox(width: 16, height: 16),
      _StatCard(
        label: 'Sélectionnées',
        value: '0',
      ),
      const SizedBox(width: 16, height: 16),
      _StatCard(
        label: 'Valeur totale estimée',
        value: '150-200 TND',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(children: stats);
        }
        return Row(children: stats);
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterAndList extends StatelessWidget {
  final _CollectorSection section;

  const _FilterAndList({required this.section});

  @override
  Widget build(BuildContext context) {
    if (section != _CollectorSection.availableAds) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          section == _CollectorSection.optimizedRoute
              ? 'Tournée optimisée (à venir)'
              : 'Profil collecteur (à venir)',
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF4B5563),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtrer par type de matériau',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                  ),
                  value: 'all',
                  icon:
                      const Icon(Icons.keyboard_arrow_down_rounded),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('Tous les matériaux'),
                    ),
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
                  ],
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _AdCard(),
      ],
    );
  }
}

class _AdCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            child: Container(
              height: 140,
              color: const Color(0xFF064E3B),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C27A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Carton',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Distance 2.3 km',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: Color(0xFF6B7280),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Ariana, près du centre commercial',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Estimé: 40 kg · 30-40 TND',
                  style: TextStyle(
                    fontSize: 13,
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

