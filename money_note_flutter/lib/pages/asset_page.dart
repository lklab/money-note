import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:money_note_flutter/data/asset_storage.dart';
import 'package:money_note_flutter/pages/asset_edit_page.dart';
import 'package:money_note_flutter/pages/asset_group_edit_page.dart';
import 'package:money_note_flutter/widgets/asset_group_item.dart';
import 'package:money_note_flutter/widgets/asset_item.dart';

class AssetPage extends StatefulWidget {
  const AssetPage({super.key});

  @override
  State<AssetPage> createState() => _AssetPageState();
}

class _AssetPageState extends State<AssetPage> {
  List<DragAndDropList> _lists = [];// = [
  //   DragAndDropList(
  //     header: _header('Group A'),
  //     children: [for (final t in ['A1','A2']) DragAndDropItem(child: _tile(t))],
  //   ),
  //   DragAndDropList(
  //     header: _header('Group B'),
  //     children: [for (final t in ['B1','B2','B3']) DragAndDropItem(child: _tile(t))],
  //   ),
  //   DragAndDropList(
  //     header: _header('Group C'),
  //     children: [DragAndDropItem(child: _tile('C1'))],
  //   ),
  // ];

  // static Widget _header(String text) => Container(
  //       color: Colors.grey.shade200, padding: const EdgeInsets.all(12),
  //       child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
  //     );
  // static Widget _tile(String text) => ListTile(
  //   title: Text(text),
  //   onTap:() {
  //     debugPrint('탭');
  //   },
  // );

  @override
  void initState() {
    super.initState();
    _updateLists();
  }

  void _updateLists() {
    _lists = [];
    final groups = AssetStorage.instance.groups;
    for (AssetGroup group in groups) {
      _lists.add(
        DragAndDropList(
          header: AssetGroupItem(
            assetGroup: group,
            onTab: (group) async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AssetGroupEditPage(assetGroup: group),
                ),
              );

              if (changed == true) {
                setState(() {
                  _updateLists();
                });
              }
            },
          ),
          children: [
            for (final asset in group.assets)
            DragAndDropItem(
              child: AssetItem(
                asset: asset,
                onTab: (asset) async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AssetEditPage(asset: asset),
                    ),
                  );

                  if (changed == true) {
                    setState(() {
                      _updateLists();
                    });
                  }
                },
              ),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DragAndDropLists(
        children: _lists,
        onItemReorder: (oldItemIndex, oldListIndex, newItemIndex, newListIndex) async {
          final groups = AssetStorage.instance.groups;

          if (oldListIndex == newListIndex && oldItemIndex <= newItemIndex) {
            ++newItemIndex;
          }

          await AssetStorage.instance.moveAsset(
            assetId: groups[oldListIndex].assets[oldItemIndex].id,
            toGroupId: groups[newListIndex].id,
            insertBeforeAssetId: newItemIndex < groups[newListIndex].assets.length ?
              groups[newListIndex].assets[newItemIndex].id : null,
          );

          setState(() {
            _updateLists();
          });
        },
        onListReorder: (oldListIndex, newListIndex) async {
          final groups = AssetStorage.instance.groups;

          if (oldListIndex <= newListIndex) {
            ++newListIndex;
          }

          await AssetStorage.instance.reorderGroup(
            groups[oldListIndex].id,
            insertBeforeGroupId: newListIndex < groups.length ? groups[newListIndex].id : null,
          );

          setState(() {
            _updateLists();
          });
        },
        listPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemDecorationWhileDragging: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(blurRadius: 8, spreadRadius: 1)],
        ),
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        spacing: 10,
        spaceBetweenChildren: 10,
        children: [
          SpeedDialChild(
            child: const FaIcon(FontAwesomeIcons.creditCard),
            label: '자산 추가',
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            onTap: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AssetEditPage(),
                ),
              );

              if (changed == true) {
                setState(() {
                  _updateLists();
                });
              }
            },
          ),
          SpeedDialChild(
            child: const FaIcon(FontAwesomeIcons.folderOpen),
            label: '자산 그룹 추가',
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            onTap: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AssetGroupEditPage(),
                ),
              );

              if (changed == true) {
                setState(() {
                  _updateLists();
                });
              }
            },
          ),
        ],
      ),
    );
  }
}
