import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HesabApp());
}

class HesabApp extends StatefulWidget {
  const HesabApp({super.key});

  @override
  State<HesabApp> createState() => _HesabAppState();
}

class _HesabAppState extends State<HesabApp> {
  bool loading = true;
  bool darkMode = false;
  String currency = 'د.ع';

  List<Map<String, dynamic>> projects = [];
  List<Map<String, dynamic>> history = [];

  Map<String, double> prices = {
    'cement': 8000,
    'brick': 250,
    'sand': 30000,
    'gravel': 35000,
    'tile': 12000,
    'paint': 15000,
    'labor': 5000,
  };

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      darkMode = prefs.getBool('darkMode') ?? false;
      currency = prefs.getString('currency') ?? 'د.ع';

      final savedProjects = prefs.getString('projects');
      final savedHistory = prefs.getString('history');
      final savedPrices = prefs.getString('prices');

      if (savedProjects != null) {
        projects = (jsonDecode(savedProjects) as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }

      if (savedHistory != null) {
        history = (jsonDecode(savedHistory) as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }

      if (savedPrices != null) {
        final decoded = jsonDecode(savedPrices) as Map;
        prices = decoded.map(
          (key, value) => MapEntry(
            key.toString(),
            (value as num).toDouble(),
          ),
        );
      }
    } catch (_) {
      projects = [];
      history = [];
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('darkMode', darkMode);
    await prefs.setString('currency', currency);
    await prefs.setString('projects', jsonEncode(projects));
    await prefs.setString('history', jsonEncode(history));
    await prefs.setString('prices', jsonEncode(prices));
  }

  Future<void> addProject(Map<String, dynamic> project) async {
    setState(() {
      projects.insert(0, project);
    });
    await persist();
  }

  Future<void> addHistory(Map<String, dynamic> item) async {
    setState(() {
      history.insert(0, item);

      if (history.length > 500) {
        history = history.take(500).toList();
      }
    });

    await persist();
  }

  Future<void> updatePrice(String key, double value) async {
    setState(() {
      prices[key] = value;
    });
    await persist();
  }

  Future<void> setTheme(bool value) async {
    setState(() => darkMode = value);
    await persist();
  }

  Future<void> setCurrency(String value) async {
    setState(() => currency = value);
    await persist();
  }

  Future<void> deleteProject(int index) async {
    setState(() => projects.removeAt(index));
    await persist();
  }

  Future<void> deleteHistory(int index) async {
    setState(() => history.removeAt(index));
    await persist();
  }

  Future<String> exportBackup() async {
    final data = {
      'version': 1,
      'currency': currency,
      'darkMode': darkMode,
      'prices': prices,
      'projects': projects,
      'history': history,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> restoreBackup(String text) async {
    final data = jsonDecode(text) as Map;

    setState(() {
      currency = data['currency']?.toString() ?? 'د.ع';
      darkMode = data['darkMode'] == true;

      final restoredPrices = data['prices'];
      if (restoredPrices is Map) {
        prices = restoredPrices.map(
          (key, value) => MapEntry(
            key.toString(),
            (value as num).toDouble(),
          ),
        );
      }

      final restoredProjects = data['projects'];
      if (restoredProjects is List) {
        projects = restoredProjects
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }

      final restoredHistory = data['history'];
      if (restoredHistory is List) {
        history = restoredHistory
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    });

    await persist();
  }

  Future<void> clearAll() async {
    setState(() {
      projects.clear();
      history.clear();
    });
    await persist();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF167D72),
      brightness: darkMode ? Brightness.dark : Brightness.light,
    );

    return MaterialApp(
      title: 'حِسبة المعلّم',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor:
            darkMode ? const Color(0xFF101615) : const Color(0xFFF4F7F6),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: darkMode ? const Color(0xFF1B2422) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: const EdgeInsets.symmetric(vertical: 6),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          filled: true,
        ),
      ),
      home: loading
          ? const LoadingScreen()
          : HomeScreen(app: this),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final _HesabAppState app;

  const HomeScreen({
    super.key,
    required this.app,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;

    final pages = [
      DashboardScreen(app: app),
      CalculatorsScreen(app: app),
      ProjectsScreen(app: app),
      HistoryScreen(app: app),
      SettingsScreen(app: app),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'حِسبة المعلّم',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'الأسعار',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PricesScreen(app: app),
                ),
              );
            },
            icon: const Icon(Icons.price_change_outlined),
          ),
        ],
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'الحاسبات',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business),
            label: 'المشاريع',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'السجل',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  final _HesabAppState app;

  const DashboardScreen({
    super.key,
    required this.app,
  });

  double get totalProjects {
    return app.projects.fold(
      0,
      (sum, item) => sum + ((item['total'] as num?)?.toDouble() ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primaryContainer,
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'حسابات البناء والتشطيب',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'احسب الكميات والتكاليف وسجّل مشاريعك في مكان واحد.',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 18),
              Text(
                'إجمالي المشاريع المسجلة',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                money(totalProjects, app.currency),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: 'المشاريع',
                value: app.projects.length.toString(),
                icon: Icons.business,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SummaryCard(
                title: 'الحسابات',
                value: app.history.length.toString(),
                icon: Icons.receipt_long,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const SectionHeading(title: 'الحاسبات السريعة'),
        const SizedBox(height: 8),
        QuickTile(
          title: 'حساب البلاط',
          subtitle: 'المساحة وعدد البلاطات وأجرة التركيب',
          icon: Icons.grid_view,
          onTap: () => openCalculator(context, app, 'tile'),
        ),
        QuickTile(
          title: 'حساب الصبغ',
          subtitle: 'مساحة الجدران والتكلفة التقديرية',
          icon: Icons.format_paint_outlined,
          onTap: () => openCalculator(context, app, 'paint'),
        ),
        QuickTile(
          title: 'حساب الإسمنت والرمل',
          subtitle: 'تقدير أولي للمواد حسب الحجم المدخل',
          icon: Icons.construction,
          onTap: () => openCalculator(context, app, 'cement'),
        ),
        QuickTile(
          title: 'حساب الطابوق',
          subtitle: 'تقدير العدد والكلفة حسب مساحة الجدار',
          icon: Icons.view_module,
          onTap: () => openCalculator(context, app, 'brick'),
        ),
        const SizedBox(height: 18),
        const SectionHeading(title: 'آخر الحسابات'),
        if (app.history.isEmpty)
          const EmptyState(
            text: 'لا توجد حسابات محفوظة بعد.',
            icon: Icons.receipt_long,
          )
        else
          ...app.history.take(4).map(
                (item) => HistoryCard(
                  item: item,
                  currency: app.currency,
                ),
              ),
      ],
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 27,
            ),
            const SizedBox(height: 10),
            Text(title),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String title;

  const SectionHeading({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class QuickTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const QuickTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 24,
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
      ),
    );
  }
}

class CalculatorsScreen extends StatelessWidget {
  final _HesabAppState app;

  const CalculatorsScreen({
    super.key,
    required this.app,
  });

  @override
  Widget build(BuildContext context) {
    final calculators = [
      ('tile', 'حساب البلاط', Icons.grid_view),
      ('paint', 'حساب الصبغ', Icons.format_paint),
      ('cement', 'حساب الإسمنت والرمل', Icons.construction),
      ('brick', 'حساب الطابوق', Icons.view_module),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeading(title: 'اختر الحاسبة'),
        const SizedBox(height: 10),
        ...calculators.map(
          (item) => QuickTile(
            title: item.$2,
            subtitle: 'إدخال القياسات وحساب التكلفة',
            icon: item.$3,
            onTap: () => openCalculator(context, app, item.$1),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.price_change),
            title: const Text('أسعار المواد'),
            subtitle: const Text('تعديل الأسعار المستخدمة في الحسابات'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PricesScreen(app: app),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

void openCalculator(
  BuildContext context,
  _HesabAppState app,
  String type,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CalculatorScreen(
        app: app,
        type: type,
      ),
    ),
  );
}

class CalculatorScreen extends StatefulWidget {
  final _HesabAppState app;
  final String type;

  const CalculatorScreen({
    super.key,
    required this.app,
    required this.type,
  });

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final firstController = TextEditingController();
  final secondController = TextEditingController();
  final thirdController = TextEditingController();
  final nameController = TextEditingController();

  double quantity = 0;
  double materialCost = 0;
  double laborCost = 0;
  double total = 0;
  String resultText = '';
  bool calculated = false;

  String get title {
    switch (widget.type) {
      case 'tile':
        return 'حساب البلاط';
      case 'paint':
        return 'حساب الصبغ';
      case 'cement':
        return 'حساب الإسمنت والرمل';
      case 'brick':
        return 'حساب الطابوق';
      default:
        return 'حاسبة البناء';
    }
  }

  @override
  void dispose() {
    firstController.dispose();
    secondController.dispose();
    thirdController.dispose();
    nameController.dispose();
    super.dispose();
  }

  double readNumber(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }

  void calculate() {
    final first = readNumber(firstController);
    final second = readNumber(secondController);
    final third = readNumber(thirdController);

    if (first <= 0 || second <= 0) {
      showMessage('أدخل قياسات صحيحة أكبر من صفر.');
      return;
    }

    final prices = widget.app.prices;

    switch (widget.type) {
      case 'tile':
        final tileSize = third > 0 ? third : 0.6;
        final area = first * second;
        final tileArea = tileSize * tileSize;

        quantity = (area / tileArea * 1.10).ceilToDouble();
        materialCost = quantity * (prices['tile'] ?? 0);
        laborCost = area * (prices['labor'] ?? 0);
        resultText =
            'المساحة: ${area.toStringAsFixed(2)} م²\n'
            'عدد البلاطات مع هدر 10%: ${quantity.toStringAsFixed(0)}';
        break;

      case 'paint':
        final area = first * second;
        final coats = third > 0 ? third : 2;
        quantity = area * coats / 10;
        materialCost = quantity * (prices['paint'] ?? 0);
        laborCost = area * (prices['labor'] ?? 0);
        resultText =
            'المساحة التقريبية: ${area.toStringAsFixed(2)} م²\n'
            'الكمية التقديرية: ${quantity.toStringAsFixed(2)} لتر';
        break;

      case 'cement':
        final volume = first * second * (third > 0 ? third : 0.1);
        quantity = volume;
        materialCost = volume * (prices['cement'] ?? 0);
        laborCost = volume * (prices['labor'] ?? 0);
        resultText =
            'الحجم المدخل: ${volume.toStringAsFixed(3)} م³\n'
            'هذا تقدير مبسط وليس تصميم خلطة إنشائية.';
        break;

      case 'brick':
        final area = first * second;
        const brickPerSquareMeter = 50.0;
        quantity = (area * brickPerSquareMeter * 1.05).ceilToDouble();
        materialCost = quantity * (prices['brick'] ?? 0);
        laborCost = area * (prices['labor'] ?? 0);
        resultText =
            'مساحة الجدار: ${area.toStringAsFixed(2)} م²\n'
            'عدد الطابوق التقديري مع هدر 5%: '
            '${quantity.toStringAsFixed(0)}';
        break;
    }

    total = materialCost + laborCost;

    setState(() {
      calculated = true;
    });
  }

  Future<void> saveResult() async {
    if (!calculated) return;

    final item = {
      'name': title,
      'details': resultText,
      'materialCost': materialCost,
      'laborCost': laborCost,
      'total': total,
      'date': DateTime.now().toIso8601String(),
    };

    await widget.app.addHistory(item);

    if (!mounted) return;
    showMessage('تم حفظ الحساب في السجل.');
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTile = widget.type == 'tile';
    final isPaint = widget.type == 'paint';
    final isCement = widget.type == 'cement';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: firstController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: isCement ? 'الطول بالمتر' : 'الطول بالمتر',
              prefixIcon: const Icon(Icons.straighten),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: secondController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: isCement ? 'العرض بالمتر' : 'العرض أو الارتفاع بالمتر',
              prefixIcon: const Icon(Icons.square_foot),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: thirdController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: isTile
                  ? 'طول ضلع البلاطة بالمتر (اختياري، الافتراضي 0.6)'
                  : isPaint
                      ? 'عدد طبقات الصبغ (اختياري، الافتراضي 2)'
                      : isCement
                          ? 'السماكة بالمتر (اختياري، الافتراضي 0.1)'
                          : 'غير مطلوب؛ اتركه فارغًا',
              prefixIcon: const Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: calculate,
            icon: const Icon(Icons.calculate),
            label: const Text('احسب التكلفة'),
          ),
          if (calculated) ...[
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'نتيجة الحساب',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(resultText),
                    const Divider(height: 28),
                    InfoRow(
                      label: 'تكلفة المواد',
                      value: money(materialCost, widget.app.currency),
                    ),
                    InfoRow(
                      label: 'أجرة العمل',
                      value: money(laborCost, widget.app.currency),
                    ),
                    const Divider(height: 20),
                    InfoRow(
                      label: 'الإجمالي',
                      value: money(total, widget.app.currency),
                      bold: true,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: saveResult,
                        icon: const Icon(Icons.save),
                        label: const Text('حفظ في السجل'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'النتائج تقديرية. تختلف الكميات الفعلية بحسب أبعاد المواد '
              'وطريقة التنفيذ والهدر والأسعار المحلية. لا تستخدم هذه '
              'الحاسبة لتحديد مواصفات العناصر الإنشائية.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 17 : 14,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectsScreen extends StatelessWidget {
  final _HesabAppState app;

  const ProjectsScreen({
    super.key,
    required this.app,
  });

  Future<void> showAddProject(BuildContext context) async {
    final nameController = TextEditingController();
    final customerController = TextEditingController();
    final amountController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة مشروع'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المشروع',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: customerController,
                decoration: const InputDecoration(
                  labelText: 'اسم العميل (اختياري)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'قيمة المشروع',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final amount =
                  double.tryParse(amountController.text.trim());

              if (name.isEmpty || amount == null || amount < 0) {
                return;
              }

              Navigator.pop(
                dialogContext,
                {
                  'name': name,
                  'customer': customerController.text.trim(),
                  'total': amount,
                  'date': DateTime.now().toIso8601String(),
                },
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    nameController.dispose();
    customerController.dispose();
    amountController.dispose();

    if (result != null) {
      await app.addProject(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: app.projects.isEmpty
          ? const EmptyState(
              text: 'لا توجد مشاريع. أضف مشروعك الأول.',
              icon: Icons.business,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: app.projects.length,
              itemBuilder: (context, index) {
                final project = app.projects[index];

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: const CircleAvatar(
                      child: Icon(Icons.business),
                    ),
                    title: Text(
                      project['name']?.toString() ?? 'مشروع',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${project['customer'] ?? 'دون اسم عميل'}\n'
                      '${money((project['total'] as num?)?.toDouble() ?? 0, app.currency)}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'حذف المشروع',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final confirm = await confirmDelete(
                          context,
                          'حذف المشروع؟',
                        );

                        if (confirm) {
                          await app.deleteProject(index);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddProject(context),
        icon: const Icon(Icons.add),
        label: const Text('مشروع جديد'),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  final _HesabAppState app;

  const HistoryScreen({
    super.key,
    required this.app,
  });

  @override
  Widget build(BuildContext context) {
    if (app.history.isEmpty) {
      return const EmptyState(
        text: 'سيظهر هنا كل حساب تحفظه من الحاسبات.',
        icon: Icons.history,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: app.history.length,
      itemBuilder: (context, index) {
        final item = app.history[index];

        return Dismissible(
          key: ValueKey(
            '${item['date'] ?? ''}-$index',
          ),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.only(right: 20),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ),
          confirmDismiss: (_) => confirmDelete(
            context,
            'حذف هذا الحساب؟',
          ),
          onDismissed: (_) => app.deleteHistory(index),
          child: HistoryCard(
            item: item,
            currency: app.currency,
          ),
        );
      },
    );
  }
}

class HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String currency;

  const HistoryCard({
    super.key,
    required this.item,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final total = (item['total'] as num?)?.toDouble() ?? 0;
    final date = DateTime.tryParse(item['date']?.toString() ?? '');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item['name']?.toString() ?? 'حساب',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  money(total, currency),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (item['details'] != null) ...[
              const SizedBox(height: 8),
              Text(item['details'].toString()),
            ],
            if (date != null) ...[
              const SizedBox(height: 8),
              Text(
                '${date.year}/${date.month}/${date.day} '
                '${date.hour.toString().padLeft(2, '0')}:'
                '${date.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PricesScreen extends StatelessWidget {
  final _HesabAppState app;

  const PricesScreen({
    super.key,
    required this.app,
  });

  static const Map<String, String> labels = {
    'cement': 'سعر كيس الإسمنت',
    'brick': 'سعر الطابوقة الواحدة',
    'sand': 'سعر الرمل للمتر المكعب',
    'gravel': 'سعر الحصى للمتر المكعب',
    'tile': 'سعر البلاطة الواحدة',
    'paint': 'سعر لتر الصبغ',
    'labor': 'أجرة العمل لكل وحدة',
  };

  Future<void> editPrice(
    BuildContext context,
    String key,
    double current,
  ) async {
    final controller = TextEditingController(
      text: current.toStringAsFixed(0),
    );

    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(labels[key] ?? key),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: InputDecoration(
            labelText: 'السعر (${app.currency})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());

              if (parsed != null && parsed >= 0) {
                Navigator.pop(dialogContext, parsed);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (value != null) {
      await app.updatePrice(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أسعار المواد')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text(
            'الأسعار الافتراضية أمثلة أولية وليست أسعار سوق محدثة. '
            'عدّلها وفق أسعار منطقتك قبل استخدام الحسابات.',
          ),
          const SizedBox(height: 12),
          ...labels.entries.map((entry) {
            final price = app.prices[entry.key] ?? 0;

            return Card(
              child: ListTile(
                title: Text(entry.value),
                subtitle: Text(money(price, app.currency)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => editPrice(
                  context,
                  entry.key,
                  price,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final _HesabAppState app;

  const SettingsScreen({
    super.key,
    required this.app,
  });

  Future<void> exportData(BuildContext context) async {
    final data = await app.exportBackup();

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('النسخة الاحتياطية'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(data),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: data),
              );

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم نسخ النسخة الاحتياطية.'),
                ),
              );
            },
            child: const Text('نسخ النص'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> importData(BuildContext context) async {
    final controller = TextEditingController();

    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استعادة نسخة احتياطية'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'الصق نص النسخة الاحتياطية هنا',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text,
            ),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (text == null || text.trim().isEmpty) return;

    try {
      await app.restoreBackup(text);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت استعادة البيانات.'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذرت الاستعادة. تحقق من صحة النص.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: SwitchListTile(
            title: const Text('الوضع الداكن'),
            subtitle: const Text('تغيير مظهر التطبيق'),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: app.darkMode,
            onChanged: app.setTheme,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('العملة'),
            subtitle: Text(app.currency),
            trailing: DropdownButton<String>(
              value: app.currency,
              items: const [
                DropdownMenuItem(
                  value: 'د.ع',
                  child: Text('دينار عراقي'),
                ),
                DropdownMenuItem(
                  value: 'ر.س',
                  child: Text('ريال سعودي'),
                ),
                DropdownMenuItem(
                  value: '\$',
                  child: Text('دولار'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  app.setCurrency(value);
                }
              },
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.price_change_outlined),
            title: const Text('إدارة الأسعار'),
            subtitle: const Text('تعديل أسعار مواد البناء'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PricesScreen(app: app),
                ),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('تصدير نسخة احتياطية'),
            subtitle: const Text('نسخ البيانات للاحتفاظ بها خارج التطبيق'),
            onTap: () => exportData(context),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('استعادة نسخة احتياطية'),
            subtitle: const Text('لصق نسخة سبق تصديرها'),
            onTap: () => importData(context),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.delete_forever_outlined,
              color: Colors.red,
            ),
            title: const Text('مسح المشاريع والسجل'),
            subtitle: const Text('لا يمسح أسعار المواد أو إعدادات التطبيق'),
            onTap: () async {
              final confirmed = await confirmDelete(
                context,
                'مسح جميع المشاريع والحسابات المحفوظة؟',
              );

              if (confirmed) {
                await app.clearAll();
              }
            },
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'حِسبة المعلّم',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const Center(
          child: Text('أداة تقديرية لحساب مواد البناء والتشطيب'),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final String text;
  final IconData icon;

  const EmptyState({
    super.key,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 54,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmDelete(
  BuildContext context,
  String message,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('تأكيد'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );

  return result ?? false;
}

String money(double amount, String currency) {
  return '${amount.toStringAsFixed(0)} $currency';
}