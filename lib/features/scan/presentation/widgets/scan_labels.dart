import 'package:flutter/widgets.dart';

import '../../../../core/localization/l10n.dart';
import '../../application/scan_controller.dart';
import '../../domain/image_quality.dart';
import '../../domain/waste_category.dart';

String recyclabilityLabel(AppLocalizations l, Recyclability r) => switch (r) {
  Recyclability.high => l.recycHigh,
  Recyclability.medium => l.recycMedium,
  Recyclability.low => l.recycLow,
};

String recyclabilityExplanation(AppLocalizations l, Recyclability r) => switch (r) {
  Recyclability.high => l.recycExplainHigh,
  Recyclability.medium => l.recycExplainMedium,
  Recyclability.low => l.recycExplainLow,
};

String issueText(AppLocalizations l, PhotoIssue i) => switch (i) {
  PhotoIssue.blurry => l.issueBlurry,
  PhotoIssue.dark => l.issueDark,
  PhotoIssue.badFraming => l.issueFraming,
};

String scanErrorText(AppLocalizations l, ScanError e) => switch (e) {
  ScanError.tooManyPhotos => l.errTooManyPhotos,
  ScanError.unsupportedFormat => l.errUnsupportedFormat,
  ScanError.unreadablePhoto => l.errUnreadablePhoto,
  ScanError.modelUnavailable => l.errModelUnavailable,
  ScanError.saveFailed => l.errSaveFailed,
};

/// Catégorie du catalogue par identifiant (repli : « autres »).
WasteCategory categoryById(List<WasteCategory> catalog, String id) =>
    catalog.where((c) => c.id == id).firstOrNull ??
    defaultCatalog.firstWhere((c) => c.id == otherCategoryId);

String languageOf(BuildContext context) => Localizations.localeOf(context).languageCode;
