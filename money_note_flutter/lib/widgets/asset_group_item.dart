import 'package:flutter/material.dart';
import 'package:money_note_flutter/data/asset_storage.dart';
import 'package:money_note_flutter/pages/asset_group_edit_page.dart';

class AssetGroupItem extends StatelessWidget {
  final AssetGroup assetGroup;
  final Function()? onUpdated;

  const AssetGroupItem({
    super.key,
    required this.assetGroup,
    this.onUpdated,
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
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => AssetGroupEditPage(assetGroup: assetGroup),
          ),
        );

        if (changed == true && onUpdated != null) {
          onUpdated!();
        }
      },
    );
  }
}
