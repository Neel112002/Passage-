import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:passage/models/payment_method.dart';
import 'package:passage/services/local_payment_methods_store.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<PaymentMethodItem> _methods = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await LocalPaymentMethodsStore.loadAll();
    setState(() {
      _methods = items;
      _loading = false;
    });
  }

  Future<void> _setDefault(String id) async {
    await LocalPaymentMethodsStore.setDefault(id);
    await _load();
  }

  Future<void> _remove(String id) async {
    await LocalPaymentMethodsStore.remove(id);
    await _load();
  }

  Future<void> _addCod() async {
    // If COD already exists, just select it (set as default) instead of creating duplicates.
    PaymentMethodItem? existing;
    try {
      existing = _methods.firstWhere((e) => e.type == PaymentMethodType.cod);
    } catch (_) {
      existing = null;
    }

    if (existing != null) {
      await LocalPaymentMethodsStore.setDefault(existing.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cash on Delivery selected')),
        );
      }
      return;
    }

    final id = UniqueKey().toString();
    final item = PaymentMethodItem(
      id: id,
      type: PaymentMethodType.cod,
      label: 'Cash on Delivery',
      details: 'Pay with cash at delivery',
      isDefault: true, // Ensure newly created COD becomes selected immediately
    );
    await LocalPaymentMethodsStore.upsert(item);
    await LocalPaymentMethodsStore.setDefault(id);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash on Delivery added and selected')),
      );
    }
  }

  Future<void> _addPaypal() async {
    final email = await _promptText(
      title: 'Connect PayPal',
      label: 'PayPal email',
      keyboard: TextInputType.emailAddress,
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Email is required';
        if (!v.contains('@')) return 'Enter a valid email';
        return null;
      },
    );
    if (email == null) return;
    final id = UniqueKey().toString();
    final item = PaymentMethodItem(
      id: id,
      type: PaymentMethodType.paypal,
      label: 'PayPal',
      details: email.trim(),
      isDefault: _methods.isEmpty,
    );
    await LocalPaymentMethodsStore.upsert(item);
    await _load();
  }

  Future<void> _addGPay() async {
    final label = await _promptText(
      title: 'Add Google Pay',
      label: 'Account label (e.g., your email)',
      keyboard: TextInputType.text,
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Label is required' : null,
    );
    if (label == null) return;
    final id = UniqueKey().toString();
    final item = PaymentMethodItem(
      id: id,
      type: PaymentMethodType.gpay,
      label: 'Google Pay',
      details: label.trim(),
      isDefault: _methods.isEmpty,
    );
    await LocalPaymentMethodsStore.upsert(item);
    await _load();
  }

  Future<void> _addCard() async {
    final card = await showModalBottomSheet<_NewCardResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16)) ),
      builder: (context) => const _AddCardSheet(),
    );
    if (card == null) return;
    final brand = _detectBrand(card.number);
    final last4 = card.number.replaceAll(RegExp(r'[^0-9]'), '').characters.takeLast(4).toString();
    final id = UniqueKey().toString();
    final item = PaymentMethodItem(
      id: id,
      type: PaymentMethodType.card,
      label: brand,
      details: '•••• $last4',
      cardBrand: brand,
      last4: last4,
      expMonth: card.expMonth,
      expYear: card.expYear,
      holderName: card.holderName,
      isDefault: _methods.isEmpty,
    );
    await LocalPaymentMethodsStore.upsert(item);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card added securely (number not stored)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Methods')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _quickActions(context),
                  const SizedBox(height: 12),
                  if (_methods.isEmpty)
                    _emptyState(context)
                  else
                    ..._methods.map((m) => _methodTile(context, m)).toList(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCard,
        icon: const Icon(Icons.credit_card, color: Colors.deepPurple),
        label: const Text('Add card'),
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a payment method', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pillButton(
                  icon: Icons.attach_money,
                  color: Colors.teal,
                  label: 'Cash on Delivery',
                  onTap: _addCod,
                ),
                _pillButton(
                  icon: Icons.account_balance_wallet_outlined,
                  color: Colors.indigo,
                  label: 'PayPal',
                  onTap: _addPaypal,
                ),
                _pillButton(
                  icon: Icons.account_balance,
                  color: Colors.green,
                  label: 'Google Pay',
                  onTap: _addGPay,
                ),
                _pillButton(
                  icon: Icons.credit_card,
                  color: Colors.deepPurple,
                  label: 'Credit/Debit Card',
                  onTap: _addCard,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Payments are stored locally for demo. To accept real payments, connect a backend in Dreamflow and integrate a payment provider.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        children: [
          const Icon(Icons.payment, size: 72, color: Colors.purple),
          const SizedBox(height: 12),
          Text('No payment methods yet', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Add a method above. You can set a default for faster checkout.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _methodTile(BuildContext context, PaymentMethodItem m) {
    final icon = switch (m.type) {
      PaymentMethodType.cod => Icons.attach_money,
      PaymentMethodType.card => Icons.credit_card,
      PaymentMethodType.paypal => Icons.account_balance_wallet_outlined,
      PaymentMethodType.gpay => Icons.account_balance,
    };
    final color = switch (m.type) {
      PaymentMethodType.cod => Colors.teal,
      PaymentMethodType.card => Colors.deepPurple,
      PaymentMethodType.paypal => Colors.indigo,
      PaymentMethodType.gpay => Colors.green,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(m.details),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Remove',
              onPressed: () => _confirmRemove(m),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
            const SizedBox(width: 4),
            Radio<String>(
              value: m.id,
              groupValue: _methods.firstWhere((e) => e.isDefault, orElse: () => _methods.isNotEmpty ? _methods.first : m).id,
              onChanged: (_) => _setDefault(m.id),
            ),
          ],
        ),
        onTap: () => _setDefault(m.id),
      ),
    );
  }

  Future<void> _confirmRemove(PaymentMethodItem m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove payment method?'),
        content: Text('Remove ${m.label} (${m.details}) from your saved payment methods?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) await _remove(m.id);
  }

  Widget _pillButton({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptText({
    required String title,
    required String label,
    required TextInputType keyboard,
    String? initialValue,
    String? Function(String?)? validator,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final formKey = GlobalKey<FormState>();
    final res = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16)) ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  keyboardType: keyboard,
                  decoration: InputDecoration(labelText: label),
                  validator: validator,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (formKey.currentState?.validate() == true) {
                      Navigator.pop(context, controller.text.trim());
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          if (formKey.currentState?.validate() == true) {
                            Navigator.pop(context, controller.text.trim());
                          }
                        },
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return res;
  }
}

class _AddCardSheet extends StatefulWidget {
  const _AddCardSheet();

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _holderController = TextEditingController();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController(); // MM/YY
  final _cvcController = TextEditingController();

  @override
  void dispose() {
    _holderController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Add card', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _holderController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Cardholder name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Cardholder name is required' : null,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.creditCardName],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _numberController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, _CardNumberFormatter()],
              decoration: const InputDecoration(labelText: 'Card number', hintText: '1234 5678 9012 3456'),
              validator: (v) {
                final raw = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                if (raw.isEmpty) return 'Card number is required';
                if (raw.length < 13 || raw.length > 19) return 'Enter a valid card number';
                if (!_luhnValid(raw)) return 'Card number is invalid';
                return null;
              },
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.creditCardNumber],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ExpiryFormatter()],
                    decoration: const InputDecoration(labelText: 'Expiry (MM/YY)', hintText: 'MM/YY'),
                    validator: (v) {
                      final text = (v ?? '').trim();
                      if (text.isEmpty) return 'Expiry is required';
                      final parts = text.split('/');
                      if (parts.length != 2) return 'Invalid expiry';
                      final m = int.tryParse(parts[0]);
                      final y2 = int.tryParse(parts[1]);
                      if (m == null || y2 == null) return 'Invalid expiry';
                      if (m < 1 || m > 12) return 'Invalid month';
                      final year = 2000 + y2;
                      final now = DateTime.now();
                      // Set to last day of month
                      final expiry = DateTime(year, m + 1, 0);
                      if (!expiry.isAfter(DateTime(now.year, now.month, 0))) {
                        return 'Card expired';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.creditCardExpirationDate],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cvcController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                    decoration: const InputDecoration(labelText: 'CVC'),
                    validator: (v) {
                      final t = (v ?? '');
                      if (t.isEmpty) return 'CVC is required';
                      if (t.length < 3 || t.length > 4) return 'Invalid CVC';
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.creditCardSecurityCode],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_circle, color: Colors.green),
                label: const Text('Save card'),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    final numberRaw = _numberController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final brand = _detectBrand(numberRaw);
    final parts = _expiryController.text.split('/');
    final m = int.parse(parts[0]);
    final y = 2000 + int.parse(parts[1]);

    Navigator.pop(context, _NewCardResult(
      holderName: _holderController.text.trim(),
      number: numberRaw,
      expMonth: m,
      expYear: y,
      brand: brand,
    ));
  }
}

class _NewCardResult {
  final String holderName;
  final String number;
  final int expMonth;
  final int expYear;
  final String brand;
  const _NewCardResult({required this.holderName, required this.number, required this.expMonth, required this.expYear, required this.brand});
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i != 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final String formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    String out;
    if (digits.length >= 3) {
      out = digits.substring(0, 2) + '/' + digits.substring(2);
    } else {
      out = digits;
    }
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}

String _detectBrand(String number) {
  // Basic brand detection by IIN/BIN ranges
  final n = number;
  if (n.startsWith('4')) return 'Visa';
  if (RegExp(r'^(5[1-5])').hasMatch(n)) return 'Mastercard';
  if (RegExp(r'^(2221|222[2-9]|22[3-9]|2[3-6]|27[01]|2720)').hasMatch(n.substring(0, n.length >= 4 ? 4 : n.length))) return 'Mastercard';
  if (RegExp(r'^(34|37)').hasMatch(n)) return 'American Express';
  if (RegExp(r'^(6011|65|64[4-9])').hasMatch(n)) return 'Discover';
  if (RegExp(r'^(352[8-9]|35[3-8])').hasMatch(n)) return 'JCB';
  if (RegExp(r'^(30[0-5]|309|36|38|39)').hasMatch(n)) return 'Diners Club';
  return 'Card';
}

bool _luhnValid(String digits) {
  int sum = 0;
  bool alt = false;
  for (int i = digits.length - 1; i >= 0; i--) {
    int n = int.parse(digits[i]);
    if (alt) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alt = !alt;
  }
  return sum % 10 == 0;
}
