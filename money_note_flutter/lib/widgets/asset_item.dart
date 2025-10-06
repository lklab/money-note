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
      onTap: onTab != null ? () {
        onTab!(asset);
      } : null,
    );
  }
}