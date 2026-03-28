import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'survey_page.dart';
import 'data_page.dart';
import 'map_page.dart';
import 'speedtest_settings_page.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Survey'),
              Tab(text: 'Data'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                const SurveyContent(),
                const DataContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MenuPage extends StatefulWidget {
  static const routeName = '/menu';
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    HomeTab(),
    MapPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 10,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset('web/gambar/Mask.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            const Text(
              'SIGAPTEL',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings Speed Test',
            onPressed: () {
              Navigator.of(context).pushNamed(SpeedtestSettingsPage.routeName);
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Survey & Data',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Maps',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.manage_accounts_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
