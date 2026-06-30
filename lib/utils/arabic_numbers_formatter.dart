import 'package:flutter/services.dart';

class ArabicNumbersFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    String newText = newValue.text;
    for (int i = 0; i < arabicDigits.length; i++) {
      newText = newText.replaceAll(arabicDigits[i], englishDigits[i]);
    }
    
    // Also handle Persian digits just in case
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    for (int i = 0; i < persianDigits.length; i++) {
      newText = newText.replaceAll(persianDigits[i], englishDigits[i]);
    }

    return newValue.copyWith(
      text: newText,
      selection: newValue.selection,
    );
  }
}
