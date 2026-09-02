import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'api_service.dart';
import '../features/profile/presentation/bloc/profile_bloc.dart';
import '../features/profile/presentation/bloc/profile_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../main.dart' show navigatorKey;
import '../widgets/payment_fail_dialog.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _isAvailable = false;
  
  Function(bool success, String? productId, String? referenceId)? onPurchaseCompleted;

  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint('IAP Error: $error');
      onPurchaseCompleted?.call(false, null, null);
    });
    
    initStoreInfo();
  }

  Future<void> initStoreInfo() async {
    _isAvailable = await _inAppPurchase.isAvailable();
    if (!_isAvailable) {
      debugPrint('IAP is not available on this device.');
      return;
    }
  }

  Future<bool> buyTopUp(String productId) async {
    if (!_isAvailable) {
      debugPrint('IAP not available');
      return false;
    }

    final ProductDetailsResponse productDetailResponse = await _inAppPurchase.queryProductDetails({productId});
    if (productDetailResponse.error != null || productDetailResponse.productDetails.isEmpty) {
      debugPrint('Product not found: ${productDetailResponse.error?.message}');
      return false;
    }

    final ProductDetails productDetails = productDetailResponse.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

    try {
      return await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);
    } catch (e) {
      debugPrint('Failed to start purchase: $e');
      return false;
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      debugPrint('IAP Event: Product ${purchaseDetails.productID}, Status: ${purchaseDetails.status}');
      
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('Purchase pending...');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase Error: ${purchaseDetails.error}');
          final activeCtx = navigatorKey.currentContext;
          if (activeCtx != null && activeCtx.mounted) {
            PaymentFailDialog.show(activeCtx);
          }
          onPurchaseCompleted?.call(false, purchaseDetails.productID, purchaseDetails.purchaseID);
          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          debugPrint('Purchase Canceled by user');
          onPurchaseCompleted?.call(false, purchaseDetails.productID, purchaseDetails.purchaseID);
          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
        } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
          
          debugPrint('Purchase successful, starting backend verification...');
          bool valid = await _verifyPurchase(purchaseDetails);
          debugPrint('Backend verification result: $valid');
          
          if (valid) {
            // Globally update wallet balance since purchase was valid
            final activeCtx = navigatorKey.currentContext;
            if (activeCtx != null && activeCtx.mounted) {
              try {
                activeCtx.read<ProfileBloc>().add(LoadProfile());
              } catch (e) {
                debugPrint('Could not read ProfileBloc from navigator context: $e');
              }
            }

            debugPrint('Triggering success callback to UI...');
            onPurchaseCompleted?.call(true, purchaseDetails.productID, purchaseDetails.purchaseID);
            
            // SECURITY: Only complete the purchase after successful server verification.
            // If we complete before verification, the user loses money on verification failure.
            if (purchaseDetails.pendingCompletePurchase) {
              debugPrint('Completing purchase with StoreKit/PlayStore...');
              await _inAppPurchase.completePurchase(purchaseDetails);
              debugPrint('Purchase completed with store.');
            }
          } else {
            final activeCtx = navigatorKey.currentContext;
            if (activeCtx != null && activeCtx.mounted) {
              PaymentFailDialog.show(activeCtx, errorMessage: 'فشل التحقق من صحة عملية الدفع.');
            }
            onPurchaseCompleted?.call(false, purchaseDetails.productID, purchaseDetails.purchaseID);
            // Do NOT complete the purchase here - let StoreKit retry on next app launch
            debugPrint('Purchase verification failed - NOT completing purchase to allow retry');
          }
        }
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      String receiptData;
      String platform;
      
      if (Platform.isIOS) {
        platform = 'ios';
        // StoreKit 2 returns a JWS token in serverVerificationData,
        // but Apple's legacy verifyReceipt API expects the App Store receipt (base64).
        // Use SKReceiptManager to get the correct receipt format.
        try {
          receiptData = await SKReceiptManager.retrieveReceiptData();
          debugPrint('iOS receipt retrieved via SKReceiptManager, length: ${receiptData.length}');
        } catch (e) {
          debugPrint('SKReceiptManager failed: $e, falling back to verificationData');
          receiptData = purchaseDetails.verificationData.serverVerificationData;
          if (receiptData.isEmpty) {
            receiptData = purchaseDetails.verificationData.localVerificationData;
          }
        }
      } else {
        platform = 'android';
        receiptData = purchaseDetails.verificationData.serverVerificationData;
        if (receiptData.isEmpty) {
          receiptData = purchaseDetails.verificationData.localVerificationData;
        }
      }
      
      if (receiptData.isEmpty) {
        debugPrint('Receipt data is empty! Cannot verify purchase.');
        return false;
      }
      
      debugPrint('Sending receipt to backend. Platform: $platform, Product: ${purchaseDetails.productID}, Receipt length: ${receiptData.length}');
      await ApiService().topupWallet(purchaseDetails.productID, platform, receiptData);
      return true;
    } catch (e) {
      debugPrint('Receipt verification failed: $e');
      return false;
    }
  }

  void dispose() {
    _subscription.cancel();
    _isInitialized = false;
  }
}
