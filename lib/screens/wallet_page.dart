import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../features/profile/presentation/bloc/profile_state.dart';
import '../features/profile/presentation/bloc/profile_bloc.dart';
import '../widgets/payment_success_dialog.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/api_service.dart';
import '../services/iap_service.dart';
import '../models/wallet_transaction.dart';
import 'package:intl/intl.dart';

class WalletPage extends StatefulWidget {
  @override
  _WalletPageState createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
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

  // Store the previous callback so we can restore it on dispose
  Function(bool success, String? productId, String? referenceId)? _previousCallback;

  @override
  void initState() {
    super.initState();

    // Save the previous callback and register our own for wallet-specific UI updates.
    // IAPService is the SINGLE source of truth for purchase stream events and server verification.
    _previousCallback = IAPService().onPurchaseCompleted;
    IAPService().onPurchaseCompleted = (success, productId, referenceId) async {
      if (!mounted) return;
      
      setState(() => _isPurchasePending = false);

      if (success) {
        // Refresh transactions list 
        await _fetchTransactions();
        
        double amount = 0;
        if (productId == 'wallet_topup_10') amount = 10;
        else if (productId == 'wallet_topup_20') amount = 20;
        else if (productId == 'wallet_topup_50') amount = 50;

        if (mounted && context.mounted) {
          PaymentSuccessDialog.show(context, amount: amount, referenceId: referenceId ?? 'N/A');
        }
      }
      // Failure dialog is already shown by IAPService itself — no duplicate here.
    };
    
    _initStoreInfo();
    _fetchTransactions();
  }

  @override
  void dispose() {
    // Restore the previous callback so other screens (like my_ads) 
    // can set their own when they become active.
    IAPService().onPurchaseCompleted = _previousCallback;
    super.dispose();
  }

  Future<void> _fetchTransactions() async {
    try {
      final data = await ApiService().getWalletTransactions();
      if (mounted) {
        setState(() {
          _transactions = data.map<WalletTransaction>((json) => WalletTransaction.fromJson(json)).toList();
          _isLoadingTransactions = false;
        });
      }
    } catch (e, stacktrace) {
      print('Error loading transactions: $e');
      print(stacktrace);
      if (mounted) {
        setState(() {
          _isLoadingTransactions = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load transactions: $e')));
      }
    }
  }

  Future<void> _initStoreInfo() async {
    final bool isAvailable = await InAppPurchase.instance.isAvailable();
    if (!isAvailable) {
      setState(() {
        _isLoadingProducts = false;
      });
      return;
    }

    ProductDetailsResponse productDetailResponse = await InAppPurchase.instance.queryProductDetails(_kProductIds.toSet());
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

  void _buyProduct(ProductDetails product) {
    setState(() => _isPurchasePending = true);
    // Delegate to IAPService which handles the purchase stream, 
    // server verification, and completePurchase in one place.
    IAPService().buyTopUp(product.id);
  }

  String _cleanProductTitle(String rawTitle) {
    String cleaned = rawTitle.replaceAll(RegExp(r'\(.*?\)'), '');
    cleaned = cleaned.replaceAll('سوقكم)', '');
    cleaned = cleaned.replaceAll('Sooqcom)', '');
    return cleaned.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('محفظتي', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 24),
                  _buildTopupSection(),
                  const SizedBox(height: 24),
                  _buildTransactionHistory(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isPurchasePending)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(child: CircularProgressIndicator()),
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
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF1E40AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white.withOpacity(0.1),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -40,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white.withOpacity(0.1),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'الرصيد المتاح',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        balance.toStringAsFixed(2),
                        style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'JOD',
                          style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopupSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'باقات شحن الرصيد',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          if (_isLoadingProducts)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_products.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد باقات شحن متاحة حالياً', style: TextStyle(color: Colors.grey))))
          else
            Column(
              children: _products.map((product) {
                
                // Determine marketing text based on product ID or price
                String title = 'باقة الشحن';
                String subtitle = 'اشحن رصيدك الآن لترويج إعلاناتك بسهولة';
                IconData icon = Icons.add_card_rounded;
                Color themeColor = Colors.blue.shade600;
                String? badge;

                if (product.id.contains('10') || product.price.contains('10')) {
                  title = 'رصيد أساسي';
                  subtitle = 'اشحن محفظتك للبدء بترويج إعلاناتك';
                  icon = Icons.rocket_launch_outlined;
                  themeColor = Colors.blue.shade600;
                } else if (product.id.contains('20') || product.price.contains('20')) {
                  title = 'رصيد متقدم';
                  subtitle = 'رصيد كافٍ لترويج إعلانات متعددة لفترة أطول';
                  icon = Icons.trending_up_rounded;
                  themeColor = Colors.indigo.shade600;
                  badge = 'الأكثر طلباً';
                } else if (product.id.contains('50') || product.price.contains('50')) {
                  title = 'رصيد الأعمال';
                  subtitle = 'الخيار الأفضل للتجار وللترويج المستمر بدون توقف';
                  icon = Icons.diamond_outlined;
                  themeColor = Colors.purple.shade600;
                  badge = 'أفضل قيمة';
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeColor.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _buyProduct(product),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: themeColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, color: themeColor, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeColor),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        subtitle,
                                        style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: themeColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    product.price,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (badge != null)
                            Positioned(
                              top: -12,
                              left: 20, // Positioned on the left side since app is RTL
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  badge,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
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

  String _getArabicTransactionType(String type) {
    switch (type.toUpperCase()) {
      case 'TOPUP':
        return 'شحن رصيد';
      case 'CLICK_DEDUCTION':
        return 'خصم تفاعل مع إعلان';
      case 'PROMOTION':
        return 'ترويج إعلان';
      default:
        return type;
    }
  }

  String _getArabicDescription(String? description) {
    if (description == null) return '';
    String desc = description;
    
    // Top-ups
    desc = desc.replaceAll('In-App Purchase Top-up (android)', 'شحن رصيد داخل التطبيق (أندرويد)');
    desc = desc.replaceAll('In-App Purchase Top-up (ios)', 'شحن رصيد داخل التطبيق (iOS)');
    
    // Interactions
    if (desc.startsWith('Action: ')) {
      desc = desc.replaceFirst('Action: call on Ad', 'اتصال على إعلان');
      desc = desc.replaceFirst('Action: view on Ad', 'مشاهدة إعلان');
      desc = desc.replaceFirst('Action: chat on Ad', 'محادثة على إعلان');
    }
    
    return desc;
  }

  Widget _buildTransactionHistory() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'سجل العمليات',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          if (_isLoadingTransactions)
            const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
          else if (_transactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 60, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('لا يوجد عمليات حتى الآن', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final tx = _transactions[index];
                bool isAddition = tx.amount > 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isAddition ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isAddition ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: isAddition ? Colors.green.shade600 : Colors.red.shade600,
                      ),
                    ),
                    title: Text(
                      _getArabicTransactionType(tx.transactionType),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${DateFormat('yyyy/MM/dd, hh:mm a').format(tx.createdAt)}\n${_getArabicDescription(tx.description)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                      ),
                    ),
                    isThreeLine: tx.description != null && tx.description!.isNotEmpty,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${isAddition ? '+' : ''}${tx.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isAddition ? Colors.green.shade600 : Colors.red.shade600,
                          ),
                        ),
                        const Text(
                          'JOD',
                          style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      ],
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
