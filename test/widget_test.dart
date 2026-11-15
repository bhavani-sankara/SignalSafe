import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/core/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('featured Hyderabad–Srisailam catalog parses', () async {
    final raw = await rootBundle.loadString('assets/mock/catalog.json');
    final catalog = Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    expect(catalog.routes.first.name, contains('NH 765'));
    expect(catalog.routes, hasLength(3));
    expect(catalog.place('srisailam').name, 'Srisailam');
    expect(catalog.towers, isNotEmpty);
  });
}
