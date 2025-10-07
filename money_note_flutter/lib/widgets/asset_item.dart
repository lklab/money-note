import 'package:flutter/material.dart';
import 'package:money_note_flutter/data/asset_storage.dart';
import 'package:money_note_flutter/pages/asset_edit_page.dart';
import 'package:money_note_flutter/pages/calculator_page.dart';
import 'package:money_note_flutter/utils/utils.dart';

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
      title: Text(
        asset.name,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
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
            Size(100, 0),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          ),
        ),
        child: Text(
          Utils.formatMoney(asset.amount),
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: Utils.getMoneyColor(asset.amount),
          ),
        ),
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0.0),
      minVerticalPadding: 0.0,
      visualDensity: const VisualDensity(vertical: -4),
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
