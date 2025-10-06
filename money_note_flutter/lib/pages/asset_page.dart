import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AssetPage extends StatefulWidget {
  const AssetPage({super.key});

  @override
  State<AssetPage> createState() => _AssetPageState();
}

class _AssetPageState extends State<AssetPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(child: Text('자산 화면', style: TextStyle(fontSize: 24))),
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
