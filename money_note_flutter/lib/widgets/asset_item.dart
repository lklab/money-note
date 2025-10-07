import 'package:flutter/material.dart';
import 'package:money_note_flutter/data/asset_storage.dart';
import 'package:money_note_flutter/pages/asset_edit_page.dart';
import 'package:money_note_flutter/pages/calculator_page.dart';

class AssetItem extends StatelessWidget {
  final Asset asset;
  final Function()? onUpdated;

  const AssetItem({
    super.key,
    required this.asset,
    this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(asset.name),
      trailing: TextButton(
        onPressed: () async {
          final result = await Navigator.push<int>(
            context,
            MaterialPageRoute(
              builder: (_) => CalculatorPage(initialValue: asset.amount),
            ),
          );

          if (result != null) {
            await AssetStorage.instance.updateAsset(asset.id, amount: result);
            if (onUpdated != null) {
              onUpdated!();
            }
          }
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
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => AssetEditPage(asset: asset),
          ),
        );

        if (changed == true && onUpdated != null) {
          onUpdated!();
        }
      },
    );
  }
}
