import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/teacher_api_service.dart';
import 'student_detail_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
class TeacherDashboardScreen extends StatefulWidget {
  final String teacherName;

  const TeacherDashboardScreen({
    Key? key,
    required this.teacherName,
  }) : super(key: key);

  @override
  _TeacherDashboardScreenState createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;
  final Color backgroundColor = const Color(0xFF0A0E21);
  final Color cardColor = const Color(0xFF1D1E33);
  final Color accentColor = const Color(0xFF24D876);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: backgroundColor,
        primaryColor: accentColor,
        cardTheme: CardThemeData(
          color: cardColor,
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      child: Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: cardColor,
              selectedIndex: _selectedIndex,
              minWidth: 90,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                  _tabController.animateTo(index);
                });
              },
              labelType: NavigationRailLabelType.all,
              leading: Column(
                children: [
                  const SizedBox(height: 30),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: accentColor, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        widget.teacherName[0].toUpperCase(),
                        style: TextStyle(fontSize: 28, color: accentColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("ADMIN", style: TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 40),
                ],
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 25.0),
                    child: IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 28),
                      onPressed: () {
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        auth.logout();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (Route<dynamic> route) => false,
                        );
                      },
                    ),
                  ),
                ),
              ),
              selectedIconTheme: IconThemeData(color: accentColor, size: 32),
              unselectedIconTheme: const IconThemeData(color: Colors.white24, size: 28),
              selectedLabelTextStyle: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelTextStyle: const TextStyle(color: Colors.white24, fontSize: 11),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), label: Text('Dashboard')),
                NavigationRailDestination(icon: Icon(Icons.groups_outlined), label: Text('Students')),
                NavigationRailDestination(icon: Icon(Icons.account_tree_outlined), label: Text('Branches')),
                NavigationRailDestination(icon: Icon(Icons.history_outlined), label: Text('Activity')),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1, color: Colors.white12),
            Expanded(
              child: Column(
                children: [
                  AppBar(
                    title: Text(
                      _destinations[_selectedIndex],
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        const OverviewTab(),
                        StudentsTab(teacherName: widget.teacherName),
                        const BranchTab(),
                        const ActivityTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<String> _destinations = [
    'Dashboard Overview',
    'Student Directory',
    'Branch Performance',
    'System Activity'
  ];
}

// ----------------------------------------------------------------------------
// Overview Tab
// ----------------------------------------------------------------------------
class OverviewTab extends StatefulWidget {
  const OverviewTab({Key? key}) : super(key: key);

  @override
  _OverviewTabState createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  Map<String, dynamic>? _overviewData;
  Map<String, dynamic>? _trendsData;
  List<dynamic>? _pulseData;
  String? _aiRecommendation;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use individual try-catch for each future to prevent one failure from breaking everything
      final results = await Future.wait([
        TeacherApiService.getDashboardOverview().catchError((e) {
          debugPrint("Overview error: $e");
          return <String, dynamic>{};
        }),
        TeacherApiService.getBatchTrends().catchError((e) {
          debugPrint("Trends error: $e");
          return <String, dynamic>{};
        }),
        TeacherApiService.getAiRecommendations().catchError((e) {
          debugPrint("AI error: $e");
          return {'recommendation': "AI insights currently unavailable."};
        }),
      ]);

      if (mounted) {
        setState(() {
          _overviewData = results[0];
          _trendsData = results[1];
          _aiRecommendation = results[2]['recommendation'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF24D876)));

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text('Connect Error: $_error',
                style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadAllData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF24D876),
                  foregroundColor: Colors.black),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: const Color(0xFF24D876),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildAIInsightCard(),
          const SizedBox(height: 25),
          _buildQuickStats(),
          const SizedBox(height: 25),
          _buildSectionHeader("Branch Distribution"),
          const SizedBox(height: 15),
          _buildBranchDistribution(),
        ],
      ),
    );
  }

  Widget _buildAIInsightCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF24D876).withOpacity(0.2),
            const Color(0xFF1D1E33).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF24D876).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF24D876).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF24D876).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF24D876), size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("AI BATCH INSIGHTS",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          color: Color(0xFF24D876),
                          fontSize: 12)),
                  Text("Smart Recommendations",
                      style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _aiRecommendation ?? "Synthesizing batch performance data...",
            style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    if (_overviewData == null || _overviewData!.isEmpty)
      return const SizedBox(height: 100, child: Center(child: Text("Analytics data currently unavailable")));

    final topBranch = _overviewData!['top_performing_branch'] ?? "N/A";
    final enrolled = (_overviewData!['total_students'] ?? 0).toString();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildGlassCard(
                "ENROLLED STUDENTS",
                enrolled,
                Icons.school_outlined,
                Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildGlassCard(
                "TOP BRANCH",
                topBranch,
                Icons.workspace_premium_rounded,
                Colors.orangeAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        _buildSectionHeader("Branch-wise Average Scores"),
        const SizedBox(height: 15),
        _buildBranchAveragesCarousel(),
        const SizedBox(height: 25),
        _buildSectionHeader("Top Students per Branch"),
        const SizedBox(height: 15),
        _buildTopStudentsCarousel(),
      ],
    );
  }

  Widget _buildBranchAveragesCarousel() {
    final branchStats = _overviewData!['branch_performance'] as List? ?? [];
    if (branchStats.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: branchStats.length,
        itemBuilder: (context, index) {
          final b = branchStats[index];
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 15),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1E33),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(b['branch'] ?? 'N/A', style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("${b['avg_score']}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF24D876))),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopStudentsCarousel() {
    if (_overviewData == null || _overviewData!['top_students_per_branch'] == null)
      return const SizedBox.shrink();

    final topStudents = _overviewData!['top_students_per_branch'] as List? ?? [];
    if (topStudents.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: topStudents.length,
        itemBuilder: (context, index) {
          final s = topStudents[index];
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 15),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1E33),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF24D876).withOpacity(0.2)),
              gradient: LinearGradient(
                colors: [const Color(0xFF24D876).withOpacity(0.05), Colors.transparent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFF24D876), size: 16),
                    const SizedBox(width: 8),
                    Text(s['branch'], style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(s['username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("${s['avg_score']}% AVG", style: const TextStyle(color: Color(0xFF24D876), fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlassCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 14),
          Text(value,
              style:
                  const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(title,
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1)),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    final trends = _trendsData?['trends'] as List? ?? [];
    if (trends.isEmpty)
      return const SizedBox(
          height: 100, child: Center(child: Text("No trend data available")));

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(10, 20, 25, 10),
      decoration: BoxDecoration(
          color: const Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(24)),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 2,
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: Colors.white10, strokeWidth: 1)),
          titlesData: FlTitlesData(
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  int idx = val.toInt();
                  if (idx >= 0 && idx < trends.length)
                    return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(trends[idx]['week'],
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white38)));
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (v, m) => Text("${(v * 10).toInt()}%",
                        style: const TextStyle(
                            fontSize: 9, color: Colors.white24)))),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                  trends.length,
                  (i) => FlSpot(i.toDouble(),
                      (trends[i]['avg_score'] as num).toDouble() / 10)),
              isCurved: true,
              color: const Color(0xFF24D876),
              barWidth: 5,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                  show: true, color: const Color(0xFF24D876).withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchDistribution() {
    if (_overviewData == null || _overviewData!['branch_distribution'] == null)
      return const SizedBox(height: 100, child: Center(child: Text("Branch data unavailable")));

    final dist = _overviewData!['branch_distribution'] as Map<String, dynamic>;
    if (dist.isEmpty)
      return const SizedBox(height: 100, child: Center(child: Text("No branch distribution data")));

    return Container(
      height: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: const Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(24)),
      child: PieChart(
        PieChartData(
          sectionsSpace: 6,
          centerSpaceRadius: 50,
          sections: dist.entries.map((e) {
            return PieChartSectionData(
              color: Colors.primaries[
                  dist.keys.toList().indexOf(e.key) % Colors.primaries.length],
              value: (e.value as num).toDouble(),
              title: e.key,
              radius: 60,
              titleStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 5, height: 22, color: const Color(0xFF24D876)),
        const SizedBox(width: 12),
        Text(title.toUpperCase(),
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white70,
                fontSize: 14)),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Students Tab
// ----------------------------------------------------------------------------
class StudentsTab extends StatefulWidget {
  final String? teacherName;
  const StudentsTab({Key? key, this.teacherName}) : super(key: key);

  @override
  _StudentsTabState createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  List<dynamic> _students = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedBranch = 'All';
  final TextEditingController _searchController = TextEditingController();
  final List<String> _branches = [
    'All',
    'CSE',
    'ECE',
    'MECH',
    'IT',
    'CSBS',
    'AI&DS',
    'AEI',
    'EEE',
    'CIVIL'
  ];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await TeacherApiService.getStudents(
          branch: _selectedBranch == 'All' ? null : _selectedBranch,
          search: _searchController.text.trim());
      if (mounted) {
        setState(() {
          _students = data['students'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- Search Bar ---
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search students by name...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54),
                onPressed: () {
                  _searchController.clear();
                  _loadStudents();
                },
              ),
              filled: true,
              fillColor: const Color(0xFF1D1E33),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onSubmitted: (_) => _loadStudents(),
          ),
        ),
        
        DefaultTabController(
          length: _branches.length,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: TabBar(
              isScrollable: true,
              indicatorColor: const Color(0xFF24D876),
              labelColor: const Color(0xFF24D876),
              unselectedLabelColor: Colors.white38,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: _branches.map((b) => Tab(text: b)).toList(),
              onTap: (index) {
                setState(() {
                  _selectedBranch = _branches[index];
                  _loadStudents();
                });
              },
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF24D876)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: _students.length,
                  itemBuilder: (context, idx) {
                    final s = _students[idx];
                    final double score = (s['avg_score'] as num).toDouble();
                    final bool isAtRisk = score < 40;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => StudentDetailScreen(
                                    username: s['username'],
                                    teacherName: widget.teacherName))),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                width: 55,
                                height: 55,
                                decoration: BoxDecoration(
                                  color: isAtRisk
                                      ? Colors.redAccent.withOpacity(0.1)
                                      : const Color(0xFF24D876)
                                          .withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    (s['username'] != null &&
                                            s['username'].toString().isNotEmpty)
                                        ? s['username']
                                            .toString()[0]
                                            .toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                        color: isAtRisk
                                            ? Colors.redAccent
                                            : const Color(0xFF24D876),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s['username'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18)),
                                    const SizedBox(height: 4),
                                    Text(
                                        "${s['branch']} • Level ${s['technical_level']}",
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12)),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: score / 100,
                                        minHeight: 6,
                                        backgroundColor: Colors.white10,
                                        color: isAtRisk
                                            ? Colors.redAccent
                                            : const Color(0xFF24D876),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              Column(
                                children: [
                                  Text("${score.toInt()}%",
                                      style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: isAtRisk
                                              ? Colors.redAccent
                                              : const Color(0xFF24D876))),
                                  const Text("SCORE",
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.white24,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Branch Tab
// ----------------------------------------------------------------------------
class BranchTab extends StatefulWidget {
  const BranchTab({Key? key}) : super(key: key);

  @override
  _BranchTabState createState() => _BranchTabState();
}

class _BranchTabState extends State<BranchTab> {
  String _selectedBranch = 'CSE';
  Map<String, dynamic>? _analyticsData;
  List<dynamic>? _leaderboardData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBranchData();
  }

  Future<void> _loadBranchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final analytics = await TeacherApiService.getBranchAnalytics(_selectedBranch);
      final ranking = await TeacherApiService.getBranchRanking(_selectedBranch);
      
      setState(() {
        _analyticsData = analytics;
        _leaderboardData = ranking['leaderboard'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            children: [
              const Text("Branch:",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white54)),
              const SizedBox(width: 15),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1E33),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBranch,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1D1E33),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF24D876)),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      items: ['CSE', 'ECE', 'MECH', 'IT', 'CSBS', 'AEI']
                          .map((String b) {
                        return DropdownMenuItem<String>(
                            value: b,
                            child: Text(b,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.white)));
                      }).toList(),
                      onChanged: (String? val) {
                        if (val != null) {
                          setState(() => _selectedBranch = val);
                          _loadBranchData();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF24D876)))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSummaryTile(),
                    const SizedBox(height: 25),
                    _buildSectionLabel("Category Strength"),
                    const SizedBox(height: 15),
                    _buildBarChart(),
                    const SizedBox(height: 25),
                    _buildSectionLabel("Full Branch Leaderboard"),
                    const SizedBox(height: 10),
                    ...(_leaderboardData ?? [])
                        .map((p) => _buildPerformerCard(p))
                        .toList(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryTile() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: const Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat("TOTAL", _analyticsData!['total_students'].toString(),
              Icons.groups_3_outlined),
          _buildMiniStat(
              "AVG SCORE",
              "${(_analyticsData!['category_averages'] as Map).values.fold(0.0, (p, c) => (p as double) + (c as num).toDouble()) / (_analyticsData!['category_averages'] as Map).length}%",
              Icons.insights_rounded),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String val, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF24D876), size: 24),
        const SizedBox(height: 8),
        Text(val,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                color: Colors.white24,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBarChart() {
    final avgs = _analyticsData!['category_averages'] as Map<String, dynamic>;
    final categories = avgs.keys.toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
      decoration: BoxDecoration(
          color: const Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(24)),
      child: BarChart(
        BarChartData(
          titlesData: FlTitlesData(
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) {
                  int i = v.toInt();
                  if (i >= 0 && i < categories.length)
                    return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(categories[i].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 8, color: Colors.white38)));
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
              categories.length,
              (i) => BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                        toY: (avgs[categories[i]] as num).toDouble(),
                        color: const Color(0xFF24D876),
                        width: 18,
                        borderRadius: BorderRadius.circular(4))
                  ])),
        ),
      ),
    );
  }

  Widget _buildPerformerCard(dynamic p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF1D1E33),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF24D876).withOpacity(0.2),
          child: Text(
            "#${p['rank']}",
            style: const TextStyle(
                color: Color(0xFF24D876), fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(p['username'],
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text("Quizzes: ${p['total_quizzes']} • Last Active: ${p['last_active']}",
            style: const TextStyle(fontSize: 10, color: Colors.white38)),
        trailing: Text("${p['avg_score']}%",
            style: const TextStyle(
                color: Color(0xFF24D876), fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Text(text.toUpperCase(),
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.white54));
}

// ----------------------------------------------------------------------------
// Activity Tab
// ----------------------------------------------------------------------------
class ActivityTab extends StatefulWidget {
  const ActivityTab({Key? key}) : super(key: key);

  @override
  _ActivityTabState createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final ds =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final data = await TeacherApiService.getDailyActivity(date: ds);
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildDatePicker(),
        const SizedBox(height: 25),
        if (_isLoading)
          const Center(
              child: CircularProgressIndicator(color: Color(0xFF24D876)))
        else if (_error != null)
          Center(child: Text("Error: $_error"))
        else ...[
          _buildActivityPulse(),
          const SizedBox(height: 25),
          _buildCompletionSummary(),
        ],
      ],
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2024),
            lastDate: DateTime.now());
        if (d != null) {
          setState(() => _selectedDate = d);
          _loadActivity();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: const Color(0xFF1D1E33),
            borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("REPORT DATE",
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.white30,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("Activity Log",
                      style: TextStyle(fontWeight: FontWeight.bold))
                ]),
            Text(
                "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                style: const TextStyle(
                    color: Color(0xFF24D876),
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityPulse() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: const Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Text("${_data?['completion_rate'] ?? 0}%",
              style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF24D876))),
          const Text("TOTAL COMPLETION",
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSimpleStat("${_data?['students_completed'] ?? 0}",
                  "SUCCESS", Colors.green),
              _buildSimpleStat("${_data?['students_missed'] ?? 0}", "MISSED",
                  Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String val, String label, Color color) =>
      Column(children: [
        Text(val,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white24))
      ]);

  Widget _buildCompletionSummary() {
    final details = (_data?['completed_details'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("COMPLETED BY",
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white54)),
        const SizedBox(height: 10),
        if (details.isEmpty)
          const Text("No completions recorded for this day.",
              style: TextStyle(color: Colors.white24))
        else
          ...details.map((d) => Card(
              child: ListTile(
                  title: Text(d['username']),
                  subtitle: Text(d['branch']),
                  trailing: const Icon(Icons.check_circle,
                      color: Color(0xFF24D876))))),
      ],
    );
  }
}
