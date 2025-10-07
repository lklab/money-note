import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:money_note_flutter/pages/asset_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final currentIndex = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    List<Widget> pages = [
      AssetPage(index: 0, indexListenable: currentIndex),
      Center(child: Text('검색 화면', style: TextStyle(fontSize: 24))),
      Center(child: Text('알림 화면', style: TextStyle(fontSize: 24))),
      Center(child: Text('설정 화면', style: TextStyle(fontSize: 24))),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: currentIndex.value,
          children: pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex.value,
        onTap: (index) {
          setState(() {
            currentIndex.value = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.wallet),
            label: '자산',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.rectangleList),
            label: '내역',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.chartPie),
            label: '예산',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.gear),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
