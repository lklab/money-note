import 'package:flutter/material.dart';
import 'package:money_note_flutter/data/asset_storage.dart';

class AssetGroupItem extends StatelessWidget {
  final AssetGroup assetGroup;
  final Function(AssetGroup)? onTab;

  const AssetGroupItem({
    super.key,
    required this.assetGroup,
    this.onTab,
  });

  @override
  Widget build(BuildContext context) {
    int sum = 0;
    for (Asset asset in assetGroup.assets) {
      sum += asset.amount;
    }

    return ListTile(
      title: Text('+ ${assetGroup.name}'),
      trailing: Text('$sum'),
      onTap: onTab != null ? () {
        onTab!(assetGroup);
      } : null,
    );
  }
}
