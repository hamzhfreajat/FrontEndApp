import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'api_service.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _isAvailable = false;
  
  Function(bool success)? onPurchaseCompleted;

  void initialize() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint('IAP Error: $error');
      onPurchaseCompleted?.call(false);
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
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('Purchase pending...');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase Error: ${purchaseDetails.error}');
          onPurchaseCompleted?.call(false);
        } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
          
          bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            onPurchaseCompleted?.call(true);
          } else {
            onPurchaseCompleted?.call(false);
          }
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      String receiptData = purchaseDetails.verificationData.serverVerificationData;
      if (receiptData.isEmpty) {
        receiptData = purchaseDetails.verificationData.localVerificationData;
      }
      
      String platform = Platform.isIOS ? 'ios' : 'android';
      
      await ApiService().topupWallet(purchaseDetails.productID, platform, receiptData);
      return true;
    } catch (e) {
      debugPrint('Receipt verification failed: $e');
      return false;
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}
