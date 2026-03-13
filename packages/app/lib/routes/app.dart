import 'package:bot_creator/main.dart';
import 'package:bot_creator/routes/app/commands.list.dart';
import 'package:bot_creator/routes/app/global.variables.dart';
import 'package:bot_creator/routes/app/home.dart';
import 'package:bot_creator/routes/app/settings.dart';
import 'package:bot_creator/routes/app/workflows.page.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/utils/responsive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart';

class AppEditPage extends StatefulWidget {
  final String appName;
  final int id;
  const AppEditPage({super.key, required this.appName, required this.id});

  @override
  State<AppEditPage> createState() => _AppEditPageState();
}

class _AppEditPageState extends State<AppEditPage>
    with TickerProviderStateMixin {
  NyxxRest? client; // Changez en nullable
  int _selectedIndex = 0;
  bool _isLoading = true;

  bool get _isDesktopPlatform {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => true,
      TargetPlatform.linux => true,
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<List<ApplicationCommand>> getCommands() async {
    if (client == null) {
      throw Exception("Client is not initialized");
    }
    final commands = await client!.commands.list();
    return commands;
  }

  Future<void> _init() async {
    await AppAnalytics.logScreenView(
      screenName: "AppEditPage",
      screenClass: "AppEditPage",
      parameters: {"app_name": widget.appName, "app_id": widget.id.toString()},
    );
    final app = await appManager.getApp(widget.id.toString());
    final token = app["token"];
    if (token != null) {
      client = await Nyxx.connectRest(token);
      setState(() {
        _isLoading = false;
        client = client;
      });
    }
  }

  List<Widget> get pageList => [
    if (client != null) AppHomePage(client: client!),
    if (client != null) AppCommandsPage(client: client!),
    if (client != null) GlobalVariablesPage(botId: client!.user.id.toString()),
    if (client != null) WorkflowsPage(botId: client!.user.id.toString()),
    if (client != null) AppSettingsPage(client: client!),
  ];

  List<_AppNavItem> _navItems(bool isSmallPhone) => [
    _AppNavItem(
      icon: Icons.home,
      label: AppStrings.t('home_tab'),
      compactLabel: AppStrings.t('home_tab'),
    ),
    _AppNavItem(
      icon: Icons.add_circle,
      label: AppStrings.t('commands_tab'),
      compactLabel: AppStrings.t('commands_tab_short'),
    ),
    _AppNavItem(
      icon: Icons.key,
      label: AppStrings.t('globals_tab'),
      compactLabel: AppStrings.t('globals_tab_short'),
    ),
    _AppNavItem(
      icon: Icons.account_tree,
      label: AppStrings.t('workflows_tab'),
      compactLabel: AppStrings.t('workflows_tab_short'),
    ),
    _AppNavItem(
      icon: Icons.settings,
      label: AppStrings.t('settings_tab'),
      compactLabel: AppStrings.t('settings_tab'),
    ),
  ];

  Widget _buildDesktopSidebar(
    BuildContext context,
    ColorScheme colorScheme,
    List<_AppNavItem> navItems,
  ) {
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  widget.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(navItems.length, (index) {
                final item = navItems[index];
                final selected = _selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color:
                            selected
                                ? colorScheme.primaryContainer
                                : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 20,
                            color:
                                selected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight:
                                    selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                color:
                                    selected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = ResponsiveHelper.isMobile(context);
    final isSmallPhone = ResponsiveHelper.isSmallPhone(context);
    final useDesktopSidebar = _isDesktopPlatform;
    final navItems = _navItems(isSmallPhone);
    final pages = pageList;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (pages.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final activeIndex =
        _selectedIndex < pages.length ? _selectedIndex : pages.length - 1;

    if (useDesktopSidebar) {
      return Scaffold(
        body: Row(
          children: [
            _buildDesktopSidebar(context, colorScheme, navItems),
            Expanded(child: pages[activeIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        type:
            isSmallPhone
                ? BottomNavigationBarType.shifting
                : BottomNavigationBarType.fixed,
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        showUnselectedLabels: !isMobile,
        currentIndex: activeIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items:
            navItems
                .map(
                  (item) => BottomNavigationBarItem(
                    icon: Icon(item.icon),
                    label: isSmallPhone ? item.compactLabel : item.label,
                    backgroundColor: colorScheme.surface,
                  ),
                )
                .toList(),
      ),
      body: pages[activeIndex],
    );
  }
}

class _AppNavItem {
  final IconData icon;
  final String label;
  final String compactLabel;

  const _AppNavItem({
    required this.icon,
    required this.label,
    required this.compactLabel,
  });
}
