import 'package:bthere_network/bthere_network.dart';
import 'package:test/test.dart';

import 'bthere_network_test.dart' show FakeAdapter, FakeTokenProvider;

Map<String, Object?> banner(int id, {String type = 'NONE'}) => {
  'bannerId': id,
  'title': 'Offer $id',
  'imageUrl': 'https://example.com/$id.png',
  'linkType': type,
};
void main() {
  test(
    'public fetch preserves order; cache isolates market and audience',
    () async {
      final adapter = FakeAdapter();
      final tokens = FakeTokenProvider();
      final client = ApiClient(
        config: NetworkConfig(baseUrl: 'https://example.com/api/v1'),
        adapter: adapter,
        tokenProvider: tokens,
      );
      addTearDown(client.close);
      final repository = MarketBannerRepository(client);
      adapter.body = {
        'marketId': 1,
        'banners': [banner(7), banner(2)],
      };
      expect((await repository.load(1, 'CUSTOMER')).map((b) => b.id), [7, 2]);
      await repository.load(1, 'CUSTOMER');
      expect(adapter.requests.length, 1);
      expect(tokens.calls, 0);
      expect(adapter.requests.single.path, '/markets/1/banners');
      expect(adapter.requests.single.queryParameters, {'audience': 'CUSTOMER'});
      await repository.load(1, 'PROVIDER');
      expect(adapter.requests.length, 2);
      adapter.body = {'marketId': 2, 'banners': []};
      expect(await repository.load(2, 'CUSTOMER'), isEmpty);
      expect(adapter.requests.length, 3);
      expect(() => repository.load(1, 'ALL'), throwsArgumentError);
    },
  );
  test('rejects wrong market and does not cache failures', () async {
    final adapter = FakeAdapter()..body = {'marketId': 2, 'banners': []};
    final client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.com/api/v1'),
      adapter: adapter,
    );
    addTearDown(client.close);
    final repository = MarketBannerRepository(client);
    await expectLater(repository.load(1, 'CUSTOMER'), throwsFormatException);
    adapter.body = {
      'marketId': 1,
      'banners': [
        banner(1),
        {...banner(2), 'endsAt': '2000-01-01T00:00:00Z'},
        {...banner(3), 'imageUrl': 'http://unsafe.example/a.png'},
      ],
    };
    expect((await repository.load(1, 'CUSTOMER')).map((b) => b.id), [1]);
  });
  test(
    'actions validate ids and HTTPS URLs without inventing destinations',
    () {
      expect(
        MarketBanner.parse({
          ...banner(1, type: 'URL'),
          'linkUrl': 'javascript:bad',
        })!.linkType,
        'NONE',
      );
      expect(
        MarketBanner.parse({
          ...banner(1, type: 'OPTION'),
          'serviceTypeId': 3,
          'optionId': 12,
        })!.linkType,
        'OPTION',
      );
      expect(MarketBanner.parse(banner(1, type: 'SERVICE'))!.linkType, 'NONE');
      expect(MarketBanner.parse({...banner(1), 'endsAt': 'bad'}), isNull);
    },
  );
}
