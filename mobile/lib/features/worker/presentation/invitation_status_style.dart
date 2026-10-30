import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/worker_invitation.dart';

extension InvitationStatusStyle on InvitationStatus {
  String label(AppLocalizations l10n) => switch (this) {
        InvitationStatus.pending => l10n.invitationPending,
        InvitationStatus.accepted => l10n.invitationAccepted,
        InvitationStatus.declined => l10n.invitationDeclined,
      };

  IconData get icon => switch (this) {
        InvitationStatus.pending => Icons.hourglass_top,
        InvitationStatus.accepted => Icons.check_circle,
        InvitationStatus.declined => Icons.cancel,
      };

  Color get color => switch (this) {
        InvitationStatus.pending => Colors.orange,
        InvitationStatus.accepted => Colors.green,
        InvitationStatus.declined => Colors.red,
      };
}
