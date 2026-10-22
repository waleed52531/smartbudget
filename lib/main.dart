import 'package:flutter/material.dart';
import 'core/user_storage/database_key_vault.dart';
import 'core/user_storage/encrypted_database_factory.dart';
import 'core/user_storage/user_database_manager.dart';
import 'features/auth/data/firebase_session_services.dart';
import 'features/auth/data/session_environment.dart';
import 'features/auth/data/session_vault.dart';
import 'features/auth/domain/lease_verifier.dart';
import 'features/auth/presentation/session_app.dart';
import 'features/auth/presentation/session_cubit.dart';
import 'core/legacy_migration/legacy_migration_service.dart';
import 'core/legacy_migration/ownership_grant.dart';
import 'features/auth/data/authorization_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final environment = SessionEnvironment.fromBuild();
    final services = await FirebaseSessionServices.initialize(environment);
    late UserDatabaseManager userStorage;
    runApp(
      AuthSessionApp(
        createSession: () => SessionCubit(
          storageFactory: (authority) => userStorage = UserDatabaseManager(
            authority: authority,
            factory: EncryptedDatabaseFactory(platformDatabaseKeyVault()),
          ),
          auth: services.auth,
          authorization: services.authorization,
          vault: SessionVault(PlatformProtectedStore(environment.projectId)),
          clock: PlatformSessionClock(),
          verifier: LeaseVerifier(
            projectId: environment.projectId,
            policyVersion: environment.policyVersion,
          ),
        ),
        createLegacyMigration: () => LegacyMigrationService(
          manager: userStorage,
          ownership: OwnershipGrantVerifier(
            () => fetchVerificationKeys(environment.keysEndpoint),
          ),
        ),
      ),
    );
  } catch (_) {
    // Configuration/initialization failure must never mount financial providers.
    runApp(const SessionUnavailableApp());
  }
}
