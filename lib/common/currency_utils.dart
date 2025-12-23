import 'package:intl/intl.dart';

/// Get currency symbol for a given ISO 4217 currency code
String currencySymbolFor(String code) {
  switch (code.toUpperCase()) {
    case 'NGN':
      return '₦';
    case 'GHS':
      return '₵';
    case 'KES':
      return 'KSh';
    case 'ZAR':
      return 'R';
    case 'EGP':
      return 'E£';
    case 'XOF':
      return 'CFA';
    case 'XAF':
      return 'FCFA';
    default:
      return '₦'; // Default to Naira symbol
  }
}

/// Get currency name for a given ISO 4217 currency code
String currencyNameFor(String code) {
  switch (code.toUpperCase()) {
    case 'NGN':
      return 'Nigerian Naira';
    case 'GHS':
      return 'Ghanaian Cedi';
    case 'KES':
      return 'Kenyan Shilling';
    case 'ZAR':
      return 'South African Rand';
    case 'EGP':
      return 'Egyptian Pound';
    case 'XOF':
      return 'West African CFA franc';
    case 'XAF':
      return 'Central African CFA franc';
    default:
      return 'Nigerian Naira'; // Default to Naira
  }
}

/// Format money amount (in cents) with currency symbol
String formatMoney(int priceCents, String currencyCode) {
  final symbol = currencySymbolFor(currencyCode);
  final value = priceCents / 100.0;

  // Use NumberFormat for proper formatting
  final fmt = NumberFormat.currency(symbol: symbol, decimalDigits: 2);

  return fmt.format(value);
}

/// Format money amount (in cents) with currency code
String formatMoneyWithCode(int priceCents, String currencyCode) {
  final code = currencyCode.toUpperCase();
  final value = priceCents / 100.0;

  final fmt = NumberFormat.currency(symbol: '', decimalDigits: 2);

  return '${fmt.format(value).trim()} $code';
}

/// List of supported African currencies
const List<String> supportedCurrencies = [
  'NGN', // Nigerian Naira (default)
  'GHS', // Ghanaian Cedi
  'KES', // Kenyan Shilling
  'ZAR', // South African Rand
  'EGP', // Egyptian Pound
  'XOF', // West African CFA franc
  'XAF', // Central African CFA franc
];

/// Get display string for currency (symbol + code)
String getCurrencyDisplay(String code) {
  final symbol = currencySymbolFor(code);
  return '$symbol • $code';
}

/// Format money with shop's currency (in cents)
String formatMoneyWithShopCurrency(int priceCents, String currencyCode) {
  final symbol = currencySymbolFor(currencyCode);
  final value = priceCents / 100.0;

  // Use NumberFormat for proper formatting
  final fmt = NumberFormat.currency(symbol: symbol, decimalDigits: 2);

  return fmt.format(value);
}

/// Get currency symbol for shop's currency (defaults to Naira)
String getShopCurrencySymbol(String currencyCode) {
  return currencySymbolFor(currencyCode);
}
