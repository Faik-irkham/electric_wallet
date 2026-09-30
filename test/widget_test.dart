import 'package:electric_wallet/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('format rupiah', () {
    expect(formatRupiahShort(100000), 'Rp 100rb');
    expect(formatRupiahShort(2500000), 'Rp 2,5jt');
    expect(formatRupiah(6400000), 'Rp 6.400.000');
  });
}
