import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/pref_key.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const PrefKey<bool> _flag = PrefKey<bool>('flag', PrefType.boolean, true);
const PrefKey<int> _count = PrefKey<int>('count', PrefType.integer, 0);
const PrefKey<String> _text = PrefKey<String>('text', PrefType.string, '');
const PrefKey<List<String>> _list = PrefKey<List<String>>(
  'list',
  PrefType.stringList,
  <String>['Default'],
);

Future<PrefsStore> _storeWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return PrefsStore(preferences: await SharedPreferences.getInstance());
}

void main() {
  test('open() reads the legacy SharedPreferences store', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'count': 42});

    final PrefsStore store = await PrefsStore.open();

    expect(store.read(_count), 42);
  });

  test('reads what v1.7 stored, for every storage type, and an absent key '
      'as its default', () async {
    final PrefsStore store = await _storeWith(<String, Object>{
      'count': 7,
      'text': 'hello',
      // The platform channel decodes lists as List<Object?>, not
      // List<String>.
      'list': <Object>['Default', 'Work'],
    });

    expect(store.read(_flag), isTrue, reason: 'absent: the default');
    expect(store.read(_count), 7);
    expect(store.read(_text), 'hello');
    expect(store.read(_list), <String>['Default', 'Work']);
  });

  test('a value stored with another type reads as the default', () async {
    final PrefsStore store = await _storeWith(<String, Object>{
      'flag': 'yes',
      'count': 'seven',
      'text': 3,
      'list': 'Default',
    });

    expect(store.read(_flag), isTrue);
    expect(store.read(_count), 0);
    expect(store.read(_text), '');
    expect(store.read(_list), <String>['Default']);
  });

  test('writes land under the exact name in the legacy store', () async {
    final PrefsStore store = await _storeWith(<String, Object>{});

    await store.write(_flag, false);
    await store.write(_count, 3);
    await store.write(_text, 'x');
    await store.write(_list, <String>['Default', 'Kids']);

    final SharedPreferences legacy = await SharedPreferences.getInstance();
    expect(legacy.getBool('flag'), isFalse);
    expect(legacy.getInt('count'), 3);
    expect(legacy.getString('text'), 'x');
    expect(legacy.getStringList('list'), <String>['Default', 'Kids']);
    expect(store.read(_count), 3);
  });

  test('remove, or writing null to an optional key, deletes the key so it '
      'reads as its default again', () async {
    const PrefKey<bool?> triState = PrefKey<bool?>(
      'tri',
      PrefType.boolean,
      null,
    );
    final PrefsStore store = await _storeWith(<String, Object>{
      'tri': false,
      'count': 9,
    });

    await store.write(triState, null);
    await store.remove(_count);

    expect(store.contains(triState), isFalse);
    expect(store.read(triState), isNull);
    expect(store.contains(_count), isFalse);
    expect(store.read(_count), 0);
  });

  test(
    'a value of the wrong type is rejected before touching the store',
    () async {
      final PrefsStore store = await _storeWith(<String, Object>{
        'flag': false,
      });

      // Inference widens T to Object when the value does not match the key.
      await expectLater(
        store.write<Object?>(_flag, 'yes'),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message,
            'message',
            contains('flag'),
          ),
        ),
      );
      expect(store.read(_flag), isFalse);
    },
  );
}
