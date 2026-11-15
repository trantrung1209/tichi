/// Bước đầu tiên khi mở app: hỏi tên gọi để Tichi chào người dùng. Chỉ lưu
/// khi bấm Bắt đầu; thoát giữa chừng thì lần sau hỏi lại.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/store.dart';
import '../app/strings.dart';
import '../app/theme.dart';
import '../core/finance/finance_core.dart';
import 'brand.dart';
import '../core/l10n.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      StoreScope.read(context).setUserName(_name.text);
      HapticFeedback.lightImpact();
    } on FinanceException catch (error) {
      setState(() => _error = friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.6, end: 1),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: const Center(child: TichiAppIcon(size: 84)),
                    ),
                    const SizedBox(height: 32),
                    Text(TichiStrings.nameTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 26,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: TichiColors.ink)),
                    const SizedBox(height: 10),
                    Text(TichiStrings.nameLead,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: TichiColors.muted)),
                    const SizedBox(height: 32),
                    TextField(
                      key: const Key('name-field'),
                      controller: _name,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      maxLength: AppStore.maxNameLength,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: TichiStrings.nameHint,
                        counterText: '',
                        errorText: _error,
                        filled: true,
                        fillColor: TichiColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: TichiColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: TichiColors.line),
                        ),
                      ),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    Text(TichiStrings.namePrivacy,
                        textAlign: TextAlign.center,
                        style: TichiText.label),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: FilledButton(
                key: const Key('name-start'),
                onPressed: _submit,
                child: Text(TichiStrings.nameStart),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hộp thoại đổi tên gọi, dùng ở mục Thêm. Trả về true nếu đã lưu.
Future<bool> showEditNameDialog(BuildContext context) async {
  final store = StoreScope.read(context);
  final controller = TextEditingController(text: store.userName ?? '');
  String? error;
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        void save() {
          try {
            store.setUserName(controller.text);
            Navigator.pop(dialogContext, true);
          } on FinanceException catch (e) {
            setState(() => error = friendlyError(e));
          }
        }

        return AlertDialog(
          title: Text(TichiStrings.editNameTitle),
          content: TextField(
            key: const Key('edit-name-field'),
            controller: controller,
            autofocus: true,
            maxLength: AppStore.maxNameLength,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: TichiStrings.editNameLabel,
              errorText: error,
            ),
            onSubmitted: (_) => save(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr('Hủy', 'Cancel')),
            ),
            TextButton(
              key: const Key('edit-name-save'),
              onPressed: save,
              child: Text(tr('Lưu', 'Save')),
            ),
          ],
        );
      },
    ),
  );
  return saved ?? false;
}
