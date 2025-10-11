import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:money_note/data/asset_storage.dart';
import 'package:money_note/pages/asset_group_edit_page.dart';
import 'package:money_note/utils/utils.dart';

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
      title: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.folderOpen,
            size: 16,
            color: Theme.of(context).primaryColor,
          ),
          SizedBox(width: 8),
          Text(
            assetGroup.name,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      trailing: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(
          Utils.formatMoney(sum),
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
            color: Utils.getMoneyColor(sum),
            fontWeight: FontWeight.w500,
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
