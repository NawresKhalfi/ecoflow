import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../estimation/application/estimation_providers.dart';
import '../../estimation/domain/estimate_record.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/data/document_picker.dart';
import '../../profile/domain/address.dart';
import '../../profile/domain/collector_document.dart';
import '../domain/collection_request.dart';
import '../domain/geo.dart';
import '../domain/service_zone.dart';
import '../domain/time_slot.dart';
import 'collection_providers.dart';
import 'matching_service.dart';

enum LocationMode { gps, saved, map }

enum RequestFormError {
  outOfZone,
  noLocation,
  noSlot,
  slotFull,
  tooLong,
  photoTooLarge,
  estimateUnavailable,
  failed,
}

class RequestFormState {
  const RequestFormState({
    this.estimate,
    this.mode = LocationMode.map,
    this.point,
    this.address = '',
    this.locating = false,
    this.slot,
    this.instructions = '',
    this.photo,
    this.recurrence = Recurrence.none,
    this.submitting = false,
    this.error,
    this.createdId,
  });

  final EstimateRecord? estimate;
  final LocationMode mode;
  final GeoPoint? point;
  final String address;
  final bool locating;
  final TimeSlot? slot;
  final String instructions;
  final Uint8List? photo;
  final Recurrence recurrence;
  final bool submitting;
  final RequestFormError? error;
  final String? createdId;

  RequestFormState copyWith({
    EstimateRecord? estimate,
    LocationMode? mode,
    GeoPoint? point,
    String? address,
    bool? locating,
    TimeSlot? slot,
    String? instructions,
    Uint8List? photo,
    bool clearPhoto = false,
    Recurrence? recurrence,
    bool? submitting,
    RequestFormError? error,
    String? createdId,
  }) => RequestFormState(
    estimate: estimate ?? this.estimate,
    mode: mode ?? this.mode,
    point: point ?? this.point,
    address: address ?? this.address,
    locating: locating ?? this.locating,
    slot: slot ?? this.slot,
    instructions: instructions ?? this.instructions,
    photo: clearPhoto ? null : (photo ?? this.photo),
    recurrence: recurrence ?? this.recurrence,
    submitting: submitting ?? this.submitting,
    error: error,
    createdId: createdId ?? this.createdId,
  );
}

/// Formulaire de demande de collecte (US-031 à US-033, US-037).
class RequestFormController extends Notifier<RequestFormState> {
  @override
  RequestFormState build() => const RequestFormState();

  List<ServiceZone> get _zones => ref.read(collectionConfigProvider).value?.zones ?? defaultZones;

  /// Zone desservie du point choisi (null = hors zone).
  ServiceZone? get zone => state.point == null ? null : zoneFor(state.point!, _zones);

  Future<void> load(String estimateCode) async {
    final record = await ref.read(estimateRepositoryProvider).fetch(estimateCode);
    if (!ref.mounted) return;
    state = record == null || record.isWeighed || record.requestId != null
        ? const RequestFormState(error: RequestFormError.estimateUnavailable)
        : RequestFormState(estimate: record);
  }

  /// Épingle déplacée sur la carte : nouvelle position + adresse inversée.
  Future<void> setPoint(GeoPoint p, {LocationMode? mode, String? address}) async {
    state = state.copyWith(point: p, mode: mode, address: address ?? state.address);
    if (address != null) return;
    final resolved = await ref.read(reverseGeocoderProvider).addressOf(p);
    if (ref.mounted && state.point == p && resolved != null) {
      state = state.copyWith(address: resolved);
    }
  }

  Future<void> useGps() async {
    state = state.copyWith(locating: true, mode: LocationMode.gps);
    final pos = await ref.read(locationServiceProvider).currentPosition();
    if (!ref.mounted) return;
    state = state.copyWith(
      locating: false,
      error: pos == null ? RequestFormError.noLocation : null,
    );
    if (pos != null) await setPoint(GeoPoint(pos.latitude, pos.longitude), mode: LocationMode.gps);
  }

  Future<void> useSavedAddress(SavedAddress a) async {
    if (!a.hasPosition) {
      state = state.copyWith(error: RequestFormError.noLocation);
      return;
    }
    await setPoint(
      GeoPoint(a.latitude!, a.longitude!),
      mode: LocationMode.saved,
      address: '${a.street}, ${a.city}',
    );
  }

  void setAddress(String v) => state = state.copyWith(address: v);
  void setSlot(TimeSlot s) => state = state.copyWith(slot: s);
  void setInstructions(String v) => state = state.copyWith(instructions: v);
  void setRecurrence(Recurrence r) => state = state.copyWith(recurrence: r);
  void removePhoto() => state = state.copyWith(clearPhoto: true);

  Future<void> pickPhoto(PickSource source) async {
    final f = await ref.read(documentPickerProvider).pick(source);
    if (f == null || !ref.mounted) return;
    state = f.bytes.length > maxDocumentBytes
        ? state.copyWith(error: RequestFormError.photoTooLarge)
        : state.copyWith(photo: f.bytes);
  }

  RequestFormError? _validate(Map<String, int> counts, int capacity) {
    if (state.point == null) return RequestFormError.noLocation;
    if (zone == null) return RequestFormError.outOfZone;
    final slot = state.slot;
    if (slot == null || !slot.start.isAfter(ref.read(clockProvider)().add(bookingLead))) {
      return RequestFormError.noSlot;
    }
    if (isSlotFull(counts, slot, capacity)) return RequestFormError.slotFull;
    if (state.instructions.trim().length > maxInstructionsLength) return RequestFormError.tooLong;
    return null;
  }

  /// Crée la demande puis lance la recherche de collecteur.
  Future<String?> submit() async {
    final estimate = state.estimate;
    final uid = ref.read(currentUidProvider);
    if (estimate == null || uid == null) return null;
    final z = zone;
    final counts = z == null
        ? const <String, int>{}
        : (ref.read(slotCountsProvider(z.id)).value ?? const {});
    final capacity = ref.read(collectionConfigProvider).value?.slotCapacity ?? 10;
    final invalid = _validate(counts, capacity);
    if (invalid != null) {
      state = state.copyWith(error: invalid);
      return null;
    }
    state = state.copyWith(submitting: true);
    try {
      final request = CollectionRequest(
        id: '',
        citizenUid: uid,
        estimateCode: estimate.code,
        place: CollectionPlace(point: state.point!, address: state.address.trim(), zoneId: z!.id),
        slot: state.slot!,
        estimatedKg: estimate.estimate.totalKg,
        estimatedDt: estimate.estimate.totalDt,
        instructions: state.instructions.trim(),
        recurrence: state.recurrence,
      );
      final repo = ref.read(collectionRepositoryProvider);
      final id = await repo.create(request, instructionPhoto: state.photo);
      final created = await repo.watch(id).first;
      if (created != null) await runMatching(ref, created);
      if (ref.mounted) state = state.copyWith(submitting: false, createdId: id);
      return id;
    } catch (_) {
      if (ref.mounted) state = state.copyWith(submitting: false, error: RequestFormError.failed);
      return null;
    }
  }
}

final requestFormControllerProvider =
    NotifierProvider.autoDispose<RequestFormController, RequestFormState>(
      RequestFormController.new,
    );
