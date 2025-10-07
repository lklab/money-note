import 'package:flutter/material.dart';
import 'package:money_note_flutter/data/asset_storage.dart';

class AssetItem extends StatelessWidget {
  final Asset asset;
  final Function(Asset)? onTab;

  const AssetItem({
    super.key,
    required this.asset,
    this.onTab,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(asset.name),
      trailing: TextButton(
        onPressed: () {
        },
        style: ButtonStyle(
          alignment: Alignment.centerRight,
          minimumSize: WidgetStatePropertyAll(
            Size(50, 36),   // ⬅️ 최소 가로/세로
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        child: Text(
          '${asset.amount}',
          textAlign: TextAlign.right,
        ),
      ),
      onTap: onTab != null ? () {
        onTab!(asset);
      } : null,
    );
  }
}
