import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/error_messages.dart';
import 'package:mobile/features/business/data/business_repository.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final es = lookupAppLocalizations(const Locale('es'));

  test('known errors are described in the app language', () {
    expect(describeError(es, const AuthException('Invalid login credentials', code: 'invalid_credentials')),
        'Correo o contraseña incorrectos.');
    expect(describeError(es, InvalidReferralCodeException()), 'Ese código de recomendación no existe.');
    expect(describeError(es, const StaffChangeBlockedException('BB002', 'x')), 'Ya está en tu equipo.');
    expect(describeError(es, http.ClientException('offline')), es.checkConnection);
  });

  test("the backend's own message is shown as sent; anything else gets a general message", () {
    expect(describeError(es, const ApiException(400, 'Ese IBAN no es válido.')), 'Ese IBAN no es válido.');
    expect(describeError(es, StateError('internal detail')), es.somethingWentWrong);
  });
}
