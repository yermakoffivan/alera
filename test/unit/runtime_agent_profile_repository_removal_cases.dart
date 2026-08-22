part of 'runtime_agent_profile_repository_test.dart';

void _registerAgentProfileRemovalRepositoryTests() {
  test('removal impact parses safe owner identities', () async {
    final client = _FakeRuntimeHostClient();
    client.responses['status.get'] = <String, Object?>{
      'runtimeCapabilities': <String>[
        aleraRuntimeHostAgentProfileRevisionsCapability,
        aleraRuntimeHostAgentProfileRemovalCapability,
      ],
    };
    client.responses['agentProfile.removalImpact'] = <String, Object?>{
      'profileId': 'prof_1',
      'exists': true,
      'revision': 7,
      'isDefault': true,
      'automationIds': <String>['automation-1'],
      'hasAutomationPolicy': true,
      'executionPolicyRunIds': <String>['run-1'],
      'tabs': <Object?>[
        <String, Object?>{'workspaceId': 'workspace-1', 'tabId': 'tab-1'},
      ],
    };
    final repository = RuntimeAgentProfileRepository(client);

    final impact = await repository.removalImpact(
      'prof_1',
      expectedRevision: 7,
    );

    expect(impact.hasBlockingReferences, isTrue);
    expect(impact.automationIds, <String>['automation-1']);
    expect(impact.executionPolicyRunIds, <String>['run-1']);
    expect(impact.tabs.single.tabId, 'tab-1');
    expect(
      client.payloads['agentProfile.removalImpact']!.single,
      <String, Object?>{'id': 'prof_1', 'expectedRevision': 7},
    );
  });

  test('remove sends explicit confirmation', () async {
    final client = _FakeRuntimeHostClient();
    client.responses['status.get'] = <String, Object?>{
      'runtimeCapabilities': <String>[
        aleraRuntimeHostAgentProfileRevisionsCapability,
        aleraRuntimeHostAgentProfileRemovalCapability,
      ],
    };
    client.responses['agentProfile.remove'] = <String, Object?>{
      'removed': true,
    };
    final repository = RuntimeAgentProfileRepository(client);

    await repository.remove('prof_1', expectedRevision: 7, confirmed: true);

    expect(client.payloads['agentProfile.remove']!.single, <String, Object?>{
      'id': 'prof_1',
      'expectedRevision': 7,
      'confirmed': true,
    });
  });

  test('removal impact refuses an older live host', () async {
    final client = _FakeRuntimeHostClient();
    client.responses['status.get'] = <String, Object?>{
      'runtimeCapabilities': const <String>[],
    };
    final repository = RuntimeAgentProfileRepository(client);

    await expectLater(
      repository.removalImpact('prof_1', expectedRevision: 7),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('newer runtime host'), contains('Restart Alera')),
        ),
      ),
    );
    expect(client.payloads['agentProfile.removalImpact'], isNull);
  });

  test('remove refuses an older live host without falling back', () async {
    final client = _FakeRuntimeHostClient();
    client.responses['status.get'] = <String, Object?>{
      'runtimeCapabilities': const <String>[],
    };
    final repository = RuntimeAgentProfileRepository(client);

    await expectLater(
      repository.remove('prof_1', expectedRevision: 7, confirmed: true),
      throwsA(isA<StateError>()),
    );
    expect(client.payloads['agentProfile.remove'], isNull);
  });
}
