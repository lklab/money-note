import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  // 표시할 화면 목록
  final List<Widget> _pages = const [
    Center(child: Text('홈 화면', style: TextStyle(fontSize: 24))),
    Center(child: Text('검색 화면', style: TextStyle(fontSize: 24))),
    Center(child: Text('알림 화면', style: TextStyle(fontSize: 24))),
    Center(child: Text('설정 화면', style: TextStyle(fontSize: 24))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 4개 이상일 때 필수
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
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
