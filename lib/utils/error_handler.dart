import 'package:flutter/foundation.dart';

class ErrorHandler {
  static String getFriendlyError(dynamic error) {
    debugPrint('ErrorHandler caught error: $error');
    String errorString = error.toString().toLowerCase();

    if (errorString.contains('failed to contact') || errorString.contains('timeout') || errorString.contains('socketexception') || errorString.contains('connection refused')) {
      return 'تعذر الاتصال بالخادم، يرجى التحقق من اتصالك بالإنترنت والمحاولة لاحقاً.';
    }
    
    if (errorString.contains('canceled') || errorString.contains('cancelled') || errorString.contains('error 1001')) {
      return 'تم إلغاء العملية من قبل المستخدم.';
    }

    if (errorString.contains('format') || errorString.contains('invalid')) {
      return 'حدث خطأ في معالجة البيانات، يرجى المحاولة مرة أخرى.';
    }

    if (errorString.contains('unauthorized') || errorString.contains('401')) {
      return 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.';
    }

    if (errorString.contains('not found') || errorString.contains('404')) {
      return 'المورد المطلوب غير موجود.';
    }

    // Generic fallback for unhandled raw exceptions
    if (errorString.startsWith('exception:')) {
      errorString = errorString.replaceFirst('exception:', '').trim();
    }
    
    // If it's a huge crash dump or unreadable apple auth exception, just say "حدث خطأ غير متوقع"
    if (errorString.length > 50 || errorString.contains('exception(')) {
      return 'حدث خطأ غير متوقع، يرجى المحاولة لاحقاً.';
    }

    return 'حدث خطأ غير متوقع، يرجى المحاولة لاحقاً.';
  }
}
