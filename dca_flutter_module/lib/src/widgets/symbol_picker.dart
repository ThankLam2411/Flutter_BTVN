import 'package:flutter/material.dart';

/// Bottom sheet chọn mã chứng khoán (tương đương react-select "Chọn mã CK").
Future<String?> showSymbolPicker(
  BuildContext context, {
  required List<String> symbols,
  String? selected,
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SymbolPickerSheet(symbols: symbols, selected: selected),
    );

class _SymbolPickerSheet extends StatefulWidget {
  const _SymbolPickerSheet({required this.symbols, this.selected});

  final List<String> symbols;
  final String? selected;

  @override
  State<_SymbolPickerSheet> createState() => _SymbolPickerSheetState();
}

class _SymbolPickerSheetState extends State<_SymbolPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toUpperCase();
    final items = q.isEmpty
        ? widget.symbols
        : widget.symbols.where((s) => s.contains(q)).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Tìm mã CK',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('Không tìm thấy mã phù hợp'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final s = items[i];
                        return ListTile(
                          title: Text(s),
                          trailing: s == widget.selected
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.of(context).pop(s),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
