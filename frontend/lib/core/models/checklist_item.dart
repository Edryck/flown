import 'package:freezed_annotation/freezed_annotation.dart';

part 'checklist_item.freezed.dart';
part 'checklist_item.g.dart';

/// Item de checklist de uma Task (campo `checklist`, `Json` no Prisma).
@freezed
class ChecklistItem with _$ChecklistItem {
  const factory ChecklistItem({required String text, required bool done}) = _ChecklistItem;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => _$ChecklistItemFromJson(json);
}
