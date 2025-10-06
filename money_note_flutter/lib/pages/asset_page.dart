import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AssetPage extends StatefulWidget {
  const AssetPage({super.key});

  @override
  State<AssetPage> createState() => _AssetPageState();
}

class _AssetPageState extends State<AssetPage> {
  List<DragAndDropList> lists = [
    DragAndDropList(
      header: _header('Group A'),
      children: [for (final t in ['A1','A2']) DragAndDropItem(child: _tile(t))],
    ),
    DragAndDropList(
      header: _header('Group B'),
      children: [for (final t in ['B1','B2','B3']) DragAndDropItem(child: _tile(t))],
    ),
    DragAndDropList(
      header: _header('Group C'),
      children: [DragAndDropItem(child: _tile('C1'))],
    ),
  ];

  static Widget _header(String text) => Container(
        color: Colors.grey.shade200, padding: const EdgeInsets.all(12),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      );
  static Widget _tile(String text) => ListTile(
    title: Text(text),
    onTap:() {
      debugPrint('탭');
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DragAndDropLists(
        children: lists,
        onItemReorder: (oldItemIndex, oldListIndex, newItemIndex, newListIndex) {
          setState(() {
            final moved = lists[oldListIndex].children.removeAt(oldItemIndex);
            lists[newListIndex].children.insert(newItemIndex, moved);
          });
        },
        onListReorder: (oldListIndex, newListIndex) {
          setState(() {
            final moved = lists.removeAt(oldListIndex);
            lists.insert(newListIndex, moved);
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
            onTap: () {
              debugPrint('지출 추가 선택');
            },
          ),
          SpeedDialChild(
            child: const FaIcon(FontAwesomeIcons.folderOpen),
            label: '자산 그룹 추가',
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            onTap: () {
              debugPrint('수입 추가 선택');
            },
          ),
        ],
      ),
    );
  }
}
