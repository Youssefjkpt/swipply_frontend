import 'package:flutter/cupertino.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/pages/home_page.dart';
import 'package:swipply/pages/profile.dart';
import 'package:swipply/pages/saved_jobs.dart';

class MainLayout extends StatelessWidget {
  MainLayout({super.key});
  final ValueNotifier<int> currentTabIndex = ValueNotifier(0);

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        activeColor: blue,
        inactiveColor: black_gray,
        backgroundColor: black,
        onTap: (index) {
          currentTabIndex.value = index; // ✅ Update selected tab
        },
        items: [
          BottomNavigationBarItem(
            icon: NavIcon(CupertinoIcons.house_fill,
                index: 0, currentTabIndex: currentTabIndex),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: NavIcon(CupertinoIcons.bookmark_fill,
                index: 1, currentTabIndex: currentTabIndex),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: NavIcon(CupertinoIcons.person,
                index: 2, currentTabIndex: currentTabIndex),
            label: 'Profile',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return ValueListenableBuilder(
          valueListenable: currentTabIndex,
          builder: (context, currentIndex, _) {
            switch (index) {
              case 0:
                return const HomePage();
              case 1:
                return const SavedJobs();
              case 2:
                return const Profile();
              default:
                return const Center(child: Text('Unknown tab'));
            }
          },
        );
      },
    );
  }
}

class NavIcon extends StatelessWidget {
  final IconData icon;
  final int index;
  final ValueNotifier<int> currentTabIndex; // ✅ Pass the same notifier

  const NavIcon(this.icon,
      {required this.index, required this.currentTabIndex});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: currentTabIndex,
      builder: (_, currentIndex, __) {
        final bool isSelected = currentIndex == index;
        return Icon(
          icon,
          size: isSelected ? 28 : 24,
          color: isSelected ? blue : black_gray,
        );
      },
    );
  }
}
