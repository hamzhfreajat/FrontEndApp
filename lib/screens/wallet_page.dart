import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import '../features/profile/presentation/bloc/profile_bloc.dart';
import '../features/profile/presentation/bloc/profile_state.dart';
import '../features/profile/presentation/bloc/profile_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/api_service.dart';
import '../models/wallet_transaction.dart';
import 'package:intl/intl.dart';

class WalletPage extends StatefulWidget {
  @override
  _WalletPageState createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  List<ProductDetails> _products = [];
  List<WalletTransaction> _transactions = [];
  bool _isLoadingProducts = true;
  bool _isLoadingTransactions = true;
  bool _isPurchasePending = false;

  final List<String> _kProductIds = <String>[
    'wallet_topup_10',
    'wallet_topup_20',
    'wallet_topup_50',
  ];

  @override
  void initState() {
    super.initState();
    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // handle error here.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Purchase Error: $error')));
    });
    
    _initStoreInfo();
    _fetchTransactions();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _fetchTransactions() async {
    try {
      final data = await Provider.of<ApiService>(context, listen: false).getWalletTransactions();
      if (mounted) {
        setState(() {
          _transactions = data.map((json) => WalletTransaction.fromJson(json)).toList();
          _isLoadingTransactions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTransactions = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load transactions')));
      }
    }
  }

  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      setState(() {
        _isLoadingProducts = false;
      });
      return;
    }

    ProductDetailsResponse productDetailResponse = await _inAppPurchase.queryProductDetails(_kProductIds.toSet());
    if (productDetailResponse.error != null || productDetailResponse.productDetails.isEmpty) {
      setState(() {
        _isLoadingProducts = false;
      });
      return;
    }

    setState(() {
      _products = productDetailResponse.productDetails;
      // Sort by price
      _products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      _isLoadingProducts = false;
    });
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        setState(() => _isPurchasePending = true);
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          setState(() => _isPurchasePending = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Purchase Failed')));
        } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
          await _verifyPurchase(purchaseDetails);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      String platform = purchaseDetails.verificationData.source;
      String receiptData = purchaseDetails.verificationData.serverVerificationData;
      
      await apiService.topupWallet(purchaseDetails.productID, platform, receiptData);
      
      // Update local profile balance and reload transactions
      context.read<ProfileBloc>().add(LoadProfile()); // Refresh profile to get new balance
      await _fetchTransactions();
      
      setState(() => _isPurchasePending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Top-up Successful!')));
    } catch (e) {
      setState(() => _isPurchasePending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to verify top-up on server.')));
    }
  }

  void _buyProduct(ProductDetails product) {
    late PurchaseParam purchaseParam;
    purchaseParam = PurchaseParam(productDetails: product);
    _inAppPurchase.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('My Wallet', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBalanceCard(),
                  _buildTopupSection(),
                  _buildTransactionHistory(),
                ],
              ),
            ),
          ),
          if (_isPurchasePending)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        double balance = state.profile?.walletBalance ?? 0.0;
        return Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[800]!, Colors.blue[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Available Balance',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                '${balance.toStringAsFixed(2)} JOD',
                style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopupSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top-up Wallet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          if (_isLoadingProducts)
            Center(child: CircularProgressIndicator())
          else if (_products.isEmpty)
            Text('No top-up packages available at the moment.', style: TextStyle(color: Colors.grey))
          else
            Row(
              children: _products.map((product) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _buyProduct(product),
                      child: Column(
                        children: [
                          Text(
                            product.title.replaceAll('(Classifieds App)', '').trim(),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            product.price,
                            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          Text(
            'Transaction History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          if (_isLoadingTransactions)
            Center(child: CircularProgressIndicator())
          else if (_transactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text('No transactions yet.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final tx = _transactions[index];
                bool isAddition = tx.amount > 0;
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isAddition ? Colors.green[100] : Colors.red[100],
                      child: Icon(
                        isAddition ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isAddition ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(tx.transactionType),
                    subtitle: Text(
                      '${DateFormat.yMMMd().format(tx.createdAt)} • ${tx.description ?? ''}',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      '${isAddition ? '+' : ''}${tx.amount.toStringAsFixed(2)} JOD',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isAddition ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
