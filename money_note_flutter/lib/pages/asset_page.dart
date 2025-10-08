import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:money_note_flutter/data/asset_storage.dart';
import 'package:money_note_flutter/data/record_storage.dart';
import 'package:money_note_flutter/pages/asset_edit_page.dart';
import 'package:money_note_flutter/pages/asset_group_edit_page.dart';
import 'package:money_note_flutter/utils/utils.dart';
import 'package:money_note_flutter/widgets/asset_group_item.dart';
import 'package:money_note_flutter/widgets/asset_item.dart';

class AssetPage extends StatefulWidget {
  final int index;
  final ValueListenable<int> indexListenable;

  const AssetPage({
    super.key,
    required this.index,
    required this.indexListenable,
  });

  @override
  State<AssetPage> createState() => _AssetPageState();
}

class _AssetPageState extends State<AssetPage> {
  late int _lastIndex;
  late final VoidCallback _listener;

  List<DragAndDropList> _lists = [];
  int _closing = 0;

  @override
  void initState() {
    super.initState();

    _lastIndex = widget.indexListenable.value;
    _listener = () {
      final now = widget.indexListenable.value;
      if (now == widget.index && _lastIndex != now) {
        _onPageShow();
      }
      if (_lastIndex == widget.index && now != widget.index) {
        _onPageHide();
      }
      _lastIndex = now;
    };
    widget.indexListenable.addListener(_listener);

    _updateLists();
    _updateClosing();
  }

  @override
  void dispose() {
    widget.indexListenable.removeListener(_listener);
    super.dispose();
  }

  void _onPageShow() {
    _updateClosing();
  }

  void _onPageHide() { }

  void _updateLists() {
    _lists = [];
    final groups = AssetStorage.instance.groups;
    for (AssetGroup group in groups) {
      _lists.add(
        DragAndDropList(
          header: AssetGroupItem(
            assetGroup: group,
            onUpdated: () {
              setState(() {
                _updateLists();
              });
            },
          ),
          children: [
            for (final asset in group.assets)
            DragAndDropItem(
              child: AssetItem(
                asset: asset,
                onUpdated: () {
                  setState(() {
                    _updateLists();
                  });
                },
              ),
            )
          ],
          contentsWhenEmpty: Builder(
            builder: (ctx) => Text(
              '자산이 없습니다.',
              style: Theme.of(ctx).textTheme.bodyMedium!.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        )
      );
    }
  }

  void _updateClosing() async {
    final closing = await RecordStorage().getClosingOfMonth(DateTime.now());
    setState(() {
      _closing = closing;
    });
  }

  @override
  Widget build(BuildContext context) {
    int totalAmount = 0;
    int trackingAmount = 0;

    for (AssetGroup group in AssetStorage.instance.groups) {
      for (Asset asset in group.assets) {
        totalAmount += asset.amount;
        if (asset.tracking) {
          trackingAmount += asset.amount;
        }
      }
    }

    final labels = ['총자산','총현금','장부상 현금','차액'];
    final totals = [totalAmount, trackingAmount, _closing, trackingAmount - _closing];

    return Scaffold(
      body: Column(
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
            },
            border: TableBorder.all(
              color: Theme.of(context).colorScheme.surface,
              width: 1.0,
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                children: List.generate(4, (col) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[col],
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                }),
              ),
              TableRow(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer),
                children: List.generate(4, (col) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Utils.formatMoney(totals[col]),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Utils.getMoneyColor(totals[col]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          SizedBox(height: 16.0),
          Expanded(
            child: DragAndDropLists(
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
              listPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              lastListTargetSize: 64.0,
              itemDecorationWhileDragging: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(blurRadius: 8, spreadRadius: 1)],
              ),
            ),
          ),
        ],
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
