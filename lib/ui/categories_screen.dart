/// Danh sách danh mục thu và chi, và màn hình tạo hoặc sửa danh mục.
library;

import 'package:flutter/material.dart';

import '../app/store.dart';
import '../app/theme.dart';
import '../core/finance/finance_core.dart';
import 'icons.dart';
import 'widgets.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _type = 'EXPENSE';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final all = store.allCategories(_type);
    final visible = all.where((c) => !c.isArchived).toList();
    final hidden = all.where((c) => c.isArchived).toList();

    void open(Widget screen) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));

    Widget tile(CategoryInfo category) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: IconAvatar(icon: category.icon, color: category.color),
          title: Text(category.name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => open(CategoryFormScreen(
              type: _type, categoryId: category.id)),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh mục',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Thêm danh mục',
            icon: const Icon(Icons.add),
            onPressed: () => open(CategoryFormScreen(type: _type)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'EXPENSE', label: Text('Chi')),
                ButtonSegment(value: 'INCOME', label: Text('Thu')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            GroupCard(children: [for (final c in visible) tile(c)]),
            if (hidden.isNotEmpty) ...[
              const SizedBox(height: 16),
              const FieldLabel('Đã ẩn'),
              GroupCard(children: [for (final c in hidden) tile(c)]),
            ],
          ],
        ),
      ),
    );
  }
}

class CategoryFormScreen extends StatefulWidget {
  const CategoryFormScreen({super.key, required this.type, this.categoryId});

  final String type;
  final String? categoryId;

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _name = TextEditingController();
  String _icon = 'more';
  String _color = 'stone';
  bool _archived = false;
  String? _error;

  bool get _isEdit => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    final id = widget.categoryId;
    if (id != null) {
      final category = StoreScope.read(context)
          .allCategories(widget.type)
          .firstWhere((c) => c.id == id);
      _name.text = category.name;
      _icon = category.icon;
      _color = category.color;
      _archived = category.isArchived;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final store = StoreScope.read(context);
    try {
      final id = widget.categoryId;
      if (id == null) {
        store.createCategory(
            name: _name.text, type: widget.type, icon: _icon, color: _color);
      } else {
        store.updateCategory(id, name: _name.text, icon: _icon, color: _color);
      }
    } on FinanceException catch (error) {
      setState(() => _error = friendlyError(error));
      return;
    }
    Navigator.of(context).pop();
  }

  void _toggleArchive() {
    StoreScope.read(context).setCategoryArchived(widget.categoryId!, !_archived);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Đóng',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
            _isEdit
                ? 'Sửa danh mục'
                : (widget.type == 'EXPENSE' ? 'Danh mục chi mới' : 'Danh mục thu mới'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            Center(child: IconAvatar(icon: _icon, color: _color, size: 64)),
            const SizedBox(height: 16),
            TextField(
              key: const Key('category-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Tên danh mục'),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Biểu tượng và màu'),
            IconColorPicker(
              icons: categoryIconChoices,
              iconKey: _icon,
              onIcon: (key) => setState(() => _icon = key),
              colorKey: _color,
              onColor: (key) => setState(() => _color = key),
            ),
            if (_error != null) FormError(_error!),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: Text(_isEdit ? 'Lưu' : 'Tạo danh mục')),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _toggleArchive,
                style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: Text(_archived ? 'Hiện lại danh mục' : 'Ẩn danh mục này'),
              ),
              Text(
                'Ẩn danh mục thì không chọn được khi ghi giao dịch mới. Giao '
                'dịch cũ vẫn giữ tên và biểu tượng.',
                textAlign: TextAlign.center,
                style: TichiText.label,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
