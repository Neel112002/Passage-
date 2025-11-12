import 'dart:math' as math;

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:passage/models/address.dart';
import 'package:passage/services/local_address_store.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key, this.selectMode = false});
  final bool selectMode; // If true, allow returning a selected address

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<AddressItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await LocalAddressStore.loadAll();
      if (mounted) setState(() { _items = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _items = []; _loading = false; });
    }
  }

  Future<void> _addOrEdit({AddressItem? existing}) async {
    final result = await showModalBottomSheet<AddressItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _AddressFormSheet(initial: existing),
    );
    if (result != null) {
      await LocalAddressStore.upsert(result);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existing == null ? 'Address added' : 'Address updated')),
        );
      }
    }
  }

  Future<void> _remove(AddressItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove address?'),
        content: Text('This will remove "${item.label}" at ${item.line1}. You can\'t undo this action.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await LocalAddressStore.remove(item.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address removed')));
      }
    }
  }

  Future<void> _setDefault(AddressItem item) async {
    await LocalAddressStore.setDefault(item.id);
    await _load();
  }

  void _useForDelivery(AddressItem item) {
    if (widget.selectMode) {
      Navigator.pop(context, item);
    } else {
      _setDefault(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Addresses'),
        actions: [
          if (!_loading && _items.isNotEmpty)
            IconButton(
              tooltip: 'Add address',
              onPressed: () => _addOrEdit(),
              icon: const Icon(Icons.add_location_alt_outlined, color: Colors.teal),
            )
        ],
      ),
      floatingActionButton: _items.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addOrEdit(),
              label: const Text('Add address'),
              icon: const Icon(Icons.add_location_alt),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: _items.isEmpty
                  ? _EmptyAddresses(onAdd: () => _addOrEdit())
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _AddressCard(
                          item: item,
                          onEdit: () => _addOrEdit(existing: item),
                          onDelete: () => _remove(item),
                          onMakeDefault: () => _setDefault(item),
                          onUseForDelivery: () => _useForDelivery(item),
                          selectMode: widget.selectMode,
                        );
                      },
                    ),
            ),
    );
  }
}

class _EmptyAddresses extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyAddresses({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined, size: 80, color: Colors.teal.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No addresses yet', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Add your shipping address to speed up checkout.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_location_alt, color: Colors.teal),
              label: const Text('Add address'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final AddressItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMakeDefault;
  final VoidCallback onUseForDelivery;
  final bool selectMode;
  const _AddressCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onMakeDefault,
    required this.onUseForDelivery,
    required this.selectMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: Colors.teal, size: 16),
                      const SizedBox(width: 6),
                      Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const Spacer(),
                if (item.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.blue, size: 16),
                        SizedBox(width: 4),
                        Text('Default', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(item.recipientName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${item.line1}${item.line2.isNotEmpty ? ', ' + item.line2 : ''}'),
            Text('${item.city}, ${item.state} ${item.postalCode}'),
            Text(item.countryCode),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(item.phone),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: item.isDefault ? null : onMakeDefault,
                    icon: const Icon(Icons.star, color: Colors.amber),
                    label: const Text('Make default'),
                  ),
                ),
                const SizedBox(width: 8),
                if (selectMode)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onUseForDelivery,
                      icon: const Icon(Icons.local_shipping, color: Colors.green),
                      label: const Text('Deliver here'),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit, color: Colors.indigo),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ],
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _AddressFormSheet extends StatefulWidget {
  final AddressItem? initial;
  const _AddressFormSheet({this.initial});

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();

  // Type/label handling
  final Set<String> _allowedTypes = const {'Home', 'Work', 'Other'};
  late String _selectedType;
  late final TextEditingController _customLabel;

  late final TextEditingController _recipient;
  late final TextEditingController _phone;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _postal;
  String _countryCode = 'US';
  bool _isDefault = false;
  bool _showLine2 = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    final initialLabel = i?.label ?? 'Home';
    if (_allowedTypes.contains(initialLabel)) {
      _selectedType = initialLabel;
      _customLabel = TextEditingController(text: '');
    } else {
      _selectedType = 'Other';
      _customLabel = TextEditingController(text: initialLabel);
    }

    _recipient = TextEditingController(text: i?.recipientName ?? '');
    _phone = TextEditingController(text: i?.phone ?? '');
    _line1 = TextEditingController(text: i?.line1 ?? '');
    _line2 = TextEditingController(text: i?.line2 ?? '');
    _city = TextEditingController(text: i?.city ?? '');
    _state = TextEditingController(text: i?.state ?? '');
    _postal = TextEditingController(text: i?.postalCode ?? '');
    _countryCode = i?.countryCode.isNotEmpty == true ? i!.countryCode : 'US';
    _isDefault = i?.isDefault ?? false;
    _showLine2 = ((i?.line2 ?? '').isNotEmpty);
  }

  @override
  void dispose() {
    _customLabel.dispose();
    _recipient.dispose();
    _phone.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _state.dispose();
    _postal.dispose();
    super.dispose();
  }

  String _newId() {
    final t = DateTime.now().microsecondsSinceEpoch;
    final r = (math.Random().nextDouble() * 0xFFFFFF).toInt().toRadixString(16);
    return 'addr_${t}_$r';
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      onSelect: (c) => setState(() => _countryCode = c.countryCode),
      countryListTheme: CountryListThemeData(
        inputDecoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search country'),
      ),
    );
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
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(widget.initial == null ? 'Add address' : 'Edit address',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                const SizedBox(height: 12),

                // Address type segment
                Text('Address type', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(value: 'Home', icon: Icon(Icons.home), label: Text('Home')),
                    ButtonSegment<String>(value: 'Work', icon: Icon(Icons.work), label: Text('Work')),
                    ButtonSegment<String>(value: 'Other', icon: Icon(Icons.label), label: Text('Other')),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (s) => setState(() => _selectedType = s.first),
                ),
                if (_selectedType == 'Other') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _customLabel,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Custom label',
                      prefixIcon: Icon(Icons.edit_note),
                    ),
                    validator: (v) {
                      if (_selectedType == 'Other' && (v == null || v.trim().isEmpty)) {
                        return 'Please enter a label';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 16),
                TextFormField(
                  controller: _recipient,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter full name' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 +\-()]')),
                  ],
                  decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone)),
                  validator: (v) {
                    final s = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                    return s.length < 7 ? 'Enter a valid phone' : null;
                  },
                ),

                const SizedBox(height: 12),
                TextFormField(
                  controller: _line1,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.streetAddressLine1],
                  decoration: const InputDecoration(labelText: 'Address line 1', prefixIcon: Icon(Icons.location_on)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter address' : null,
                ),
                if (_showLine2) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _line2,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.streetAddressLine2],
                    decoration: const InputDecoration(labelText: 'Address line 2 (optional)', prefixIcon: Icon(Icons.apartment)),
                    validator: (v) => null,
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => setState(() => _showLine2 = true),
                    icon: const Icon(Icons.add, color: Colors.teal),
                    label: const Text('Add apartment, suite, etc.'),
                  ),
                ],

                const SizedBox(height: 12),
                TextFormField(
                  controller: _city,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.addressCity],
                  decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.location_city)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter city' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _state,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.addressState],
                  decoration: const InputDecoration(labelText: 'State / Region', prefixIcon: Icon(Icons.map)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter state' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _postal,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.postalCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return newValue.copyWith(text: newValue.text.toUpperCase());
                    }),
                  ],
                  decoration: const InputDecoration(labelText: 'Postal code', prefixIcon: Icon(Icons.local_post_office)),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Enter postal code' : null,
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickCountry,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.25)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.public, color: Colors.indigo),
                              const SizedBox(width: 8),
                              Text('Country: $_countryCode'),
                              const Spacer(),
                              const Icon(Icons.expand_more),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: _isDefault,
                          onChanged: (v) => setState(() => _isDefault = v),
                        ),
                        const SizedBox(width: 6),
                        const Text('Set as default'),
                      ],
                    )
                  ],
                ),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.red),
                        label: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          final label = _selectedType == 'Other'
                              ? _customLabel.text.trim()
                              : _selectedType;
                          final item = AddressItem(
                            id: widget.initial?.id ?? _newId(),
                            label: label,
                            recipientName: _recipient.text.trim(),
                            phone: _phone.text.trim(),
                            line1: _line1.text.trim(),
                            line2: _line2.text.trim(),
                            city: _city.text.trim(),
                            state: _state.text.trim(),
                            postalCode: _postal.text.trim(),
                            countryCode: _countryCode,
                            isDefault: _isDefault,
                          );
                          // Return item to caller; the store decides how to enforce default uniqueness
                          if (context.mounted) Navigator.pop(context, item);
                        },
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        label: Text(widget.initial == null ? 'Save address' : 'Save changes'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
