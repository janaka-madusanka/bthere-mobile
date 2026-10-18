import 'package:provider_app/app/app.dart';
import 'package:provider_app/features/services/documents/documents_controller.dart';
import 'package:provider_app/features/services/documents/document_models.dart';

import 'support/fake_documents_repository.dart';

import 'package:provider_app/features/account/application/provider_profile_overview.dart';

import 'dart:ui' as ui;

import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider_app/app/router/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/account/presentation/provider_account_screen.dart';
import 'package:provider_app/features/onboarding/profile/domain/provider_profile_input.dart';

import 'service_first_test.dart';
import 'support/fake_profile_repository.dart';

Map<String, dynamic> profileData() => {
  'serviceProviderId': 12,
  'userId': 25,
  'marketId': 1,
  'firstName': 'Nimali',
  'lastName': 'Perera',
  'dateOfBirth': '1992-06-21',
  'gender': 'FEMALE',
  'availabilityStatus': 'AVAILABLE',
  'verificationStatus': 'PENDING',
  'averageRating': 4.8,
  'totalRatings': 128,
  'bio': 'Home care',
  'nicNumber': 'synthetic-nic',
  'profilePhoto': null,
};

void main() {
  Future<(ProviderContainer, FakeProfileRepository)> render(
    WidgetTester tester, {
    bool failSave = false,
    double width = 430,
    double scale = 1,
    ProfileSupplementRepository? supplement,
  }) async {
    final repository = FakeProfileRepository();
    if (failSave) {
      repository.result = const Failure(
        AppFailure(message: 'Synthetic failure'),
      );
    }
    final fixture = ServiceFixture(
      existing: true,
      profileData: profileData(),
      profileRepository: repository,
      profileSupplementRepository: supplement,
    );
    final container = fixture.container;
    tester.view.physicalSize = ui.Size(width, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 932),
              textScaler: TextScaler.linear(scale),
            ),
            child: const Scaffold(body: ProviderAccountScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container, repository);
  }

  testWidgets(
    'profile renders API identity, rating and expandable personal details',
    (tester) async {
      await render(tester);
      expect(find.text('Nimali Perera'), findsOneWidget);
      expect(find.text('4.8 (128 reviews)'), findsOneWidget);
      expect(find.text('Profile Verified'), findsNothing);
      expect(find.text('Skills & Languages'), findsNothing);
      expect(find.text('Availability'), findsNothing);
      expect(
        find.bySemanticsLabel('Collapse Personal Information'),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel('Collapse Documents & Verification'),
        findsNothing,
      );
      expect(find.bySemanticsLabel('Collapse Payouts'), findsNothing);
      expect(find.textContaining('1992 June 21'), findsNothing);
      await tester.tap(find.text('Personal Information'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1992 June 21'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'availability saves existing profile fields and handles failures',
    (tester) async {
      final (_, repository) = await render(tester, failSave: true);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(
        repository.input!.availabilityStatus,
        ProviderAvailability.unavailable,
      );
      expect(repository.input!.nicNumber, 'synthetic-nic');
      expect(repository.input!.bio, 'Home care');
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(
        find.text('Unable to update availability. Please try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('narrow profile supports enlarged text without overflow', (
    tester,
  ) async {
    await render(tester, width: 320, scale: 2);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Payouts'), 200);
    await tester.tap(find.text('Payouts'));
    await tester.pumpAndSettle();
    expect(find.text('Payment details are not available yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('profile visual preview uses the production navigation shell', (
    tester,
  ) async {
    for (final font in ['HomeInter', 'Nunito', 'MaterialIcons']) {
      final loader = FontLoader(font)
        ..addFont(
          rootBundle.load(
            font == 'MaterialIcons'
                ? 'fonts/MaterialIcons-Regular.otf'
                : font == 'HomeInter'
                ? 'assets/fonts/Inter.ttf'
                : 'assets/fonts/Nunito.ttf',
          ),
        );
      await loader.load();
    }
    tester.view.physicalSize = const ui.Size(430, 932);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 40, bottom: 34);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = ServiceFixture(
      existing: true,
      profileData: profileData(),
      profileSupplementRepository: FakeProfileSupplement(),
    );
    final documents =
        fixture.container.read(documentsRepositoryProvider) as FakeDocuments;
    documents.requirementsResult = const Success([
      DocumentRequirement(1, 'National ID Card', null, false, true, true),
      DocumentRequirement(2, 'Selfie', null, false, true, true),
      DocumentRequirement(3, 'Birth Certificate', null, false, true, true),
      DocumentRequirement(
        4,
        'Grama Niladhari Certificate',
        null,
        false,
        true,
        true,
      ),
    ]);
    documents.documentsResult = Success([
      for (final type in [2, 3, 4])
        ProviderDocument(
          type,
          type,
          type == 3 ? 'PENDING' : 'APPROVED',
          null,
          null,
          typeName: [
            '',
            'National ID Card',
            'Selfie',
            'Birth Certificate',
            'Grama Niladhari Certificate',
          ][type],
          createdAt: DateTime(2025, 1, 12),
        ),
    ]);
    await pump(tester, fixture, route: AppRoutes.account);
    await expectLater(
      find.byType(BThereProviderApp),
      matchesGoldenFile('goldens/provider_profile.png'),
    );
    tester.view.physicalSize = const ui.Size(430, 1409);
    await tester.pumpAndSettle();
    for (final title in [
      'Personal Information',
      'Documents & Verification',
      'Payouts',
    ]) {
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 1500),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BThereProviderApp),
      matchesGoldenFile('goldens/provider_profile_expanded.png'),
    );
    expect(tester.takeException(), isNull);
  });
}

class FakeProfileSupplement implements ProfileSupplementRepository {
  ProfileSupplement value = const ProfileSupplement(
    completedBookings: 24,
    city: 'Colombo',
    country: 'Sri Lanka',
    skills: [
      ProfileSkill(10, 'Personal Care'),
      ProfileSkill(11, 'Mobility Assistance'),
      ProfileSkill(12, 'Medication Support'),
      ProfileSkill(13, 'Heat Preparation'),
    ],
    skillCatalog: [
      ProfileSkill(10, 'Personal Care'),
      ProfileSkill(11, 'Mobility Assistance'),
      ProfileSkill(12, 'Medication Support'),
      ProfileSkill(13, 'Heat Preparation'),
      ProfileSkill(14, 'Companionship'),
    ],
    languages: ['ENGLISH', 'SINHALA', 'TAMIL'],
    workingHours: ProfileWorkingHours(
      availableAnyDay: false,
      availableAnyTime: true,
      slots: [
        ProfileDaySlot('MONDAY', null, null),
        ProfileDaySlot('TUESDAY', null, null),
        ProfileDaySlot('WEDNESDAY', null, null),
        ProfileDaySlot('THURSDAY', null, null),
        ProfileDaySlot('FRIDAY', null, null),
        ProfileDaySlot('SUNDAY', null, null),
      ],
    ),
    payout: ProfilePayout(
      method: 'Bank Transfer',
      bankName: 'Example Bank',
      accountNumber: '•••• 9012',
      accountHolder: 'Nimali Perera',
    ),
  );
  int saves = 0;
  bool failSave = false;
  @override
  Future<Result<ProfileSupplement>> load() async => Success(value);
  @override
  Future<Result<void>> saveSkillsLanguages(
    List<int> ids,
    List<String> languages,
  ) async {
    saves++;
    if (failSave) {
      return const Failure(AppFailure(message: 'Synthetic failure'));
    }
    value = ProfileSupplement(
      completedBookings: value.completedBookings,
      city: value.city,
      country: value.country,
      skills: value.skillCatalog.where((s) => ids.contains(s.id)).toList(),
      skillCatalog: value.skillCatalog,
      languages: languages,
      workingHours: value.workingHours,
      payout: value.payout,
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> saveWorkingHours(ProfileWorkingHours hours) async {
    saves++;
    value = ProfileSupplement(
      completedBookings: value.completedBookings,
      city: value.city,
      country: value.country,
      skills: value.skills,
      skillCatalog: value.skillCatalog,
      languages: value.languages,
      workingHours: hours,
      payout: value.payout,
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> savePayout(ProfilePayout payout) async {
    saves++;
    value = ProfileSupplement(
      completedBookings: value.completedBookings,
      city: value.city,
      country: value.country,
      skills: value.skills,
      skillCatalog: value.skillCatalog,
      languages: value.languages,
      workingHours: value.workingHours,
      payout: payout,
    );
    return const Success(null);
  }
}
