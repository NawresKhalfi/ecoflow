import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/action_controller.dart';
import '../domain/company_profile.dart';
import 'profile_providers.dart';

/// Il faut au moins une matière traitée.
class NoMaterialSelected implements Exception {
  const NoMaterialSelected();
}

/// Profil entreprise du recycleur, soumis à validation admin (US-007).
class CompanyController extends ActionController {
  Future<bool> submit(CompanyProfile profile) => run(() async {
        if (profile.materials.isEmpty) throw const NoMaterialSelected();
        await ref.read(companyRepositoryProvider).submit(requireUid(ref), profile);
      });
}

final companyControllerProvider =
    NotifierProvider.autoDispose<CompanyController, AsyncValue<void>>(CompanyController.new);
