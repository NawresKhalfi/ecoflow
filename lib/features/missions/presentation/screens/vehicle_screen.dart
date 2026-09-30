import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/collector_controllers.dart';
import '../../application/missions_providers.dart';
import '../../domain/vehicle.dart';
import '../widgets/mission_labels.dart';

/// Véhicule et capacité (US-054).
class VehicleScreen extends ConsumerStatefulWidget {
  const VehicleScreen({super.key});

  @override
  ConsumerState<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends ConsumerState<VehicleScreen> {
  VehicleType? _type;
  final _capacity = TextEditingController();
  final _volume = TextEditingController();
  final _plate = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in [_capacity, _volume, _plate]) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply(Vehicle v) {
    _type = v.type;
    _capacity.text = v.capacityKg.toStringAsFixed(0);
    _volume.text = v.volumeM3.toString();
    _plate.text = v.plate;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final saved = ref.watch(vehicleProvider);
    if (!_loaded && saved.hasValue) {
      _loaded = true;
      _apply(saved.value ?? Vehicle.defaultFor(VehicleType.car));
    }
    final state = ref.watch(collectorSettingsControllerProvider);
    return LayeredPage(
      header: HeroHeader(
        title: l.vehicleTitle,
        subtitle: l.vehicleSubtitle,
        emoji: vehicleEmoji(_type ?? VehicleType.van),
        gradient: EcoGradients.coral,
        leading: IconButton.filledTonal(
          tooltip: l.commonBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .22),
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.go(Routes.profile),
          icon: const BackButtonIcon(),
        ),
      ),
      children: [
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.vehicleType, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in VehicleType.values)
                    EcoChip(
                      label: '${vehicleEmoji(t)} ${vehicleLabel(l, t)}',
                      selected: _type == t,
                      onTap: () => setState(() => _apply(Vehicle.defaultFor(t))),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              EcoTextField(
                label: l.vehicleCapacity,
                emoji: '⚖️',
                controller: _capacity,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              EcoTextField(
                label: l.vehicleVolume,
                emoji: '📦',
                controller: _volume,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              EcoTextField(
                label: l.vehiclePlate,
                emoji: '🔖',
                controller: _plate,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 14),
              EcoButton(
                label: l.commonSave,
                style: EcoButtonStyle.green,
                loading: state.isLoading,
                onPressed: () async {
                  final ok = await ref
                      .read(collectorSettingsControllerProvider.notifier)
                      .saveVehicle(
                        Vehicle(
                          type: _type ?? VehicleType.car,
                          capacityKg: parseKg(_capacity.text) ?? 0,
                          volumeM3: parseKg(_volume.text) ?? 0,
                          plate: _plate.text,
                        ),
                      );
                  if (ok && context.mounted) showEcoToast(context, l.vehicleSaved);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
