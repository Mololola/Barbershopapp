import 'package:flutter/material.dart';

import '../domain/worker_invitation.dart';

extension InvitationStatusStyle on InvitationStatus {
  String get label => switch (this) {
        InvitationStatus.pending => 'Pending',
        InvitationStatus.accepted => 'Accepted',
        InvitationStatus.declined => 'Declined',
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
