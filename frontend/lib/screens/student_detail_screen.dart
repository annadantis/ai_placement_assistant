import 'package:flutter/material.dart';
import '../services/teacher_api_service.dart';

class StudentDetailScreen extends StatefulWidget {
  final String username;

  const StudentDetailScreen({
    Key? key,
    required this.username,
  }) : super(key: key);

  @override
  _StudentDetailScreenState createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await TeacherApiService.getStudentProgress(widget.username);
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
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        primaryColor: const Color(0xFF24D876),
        cardTheme: CardThemeData(
          color: const Color(0xFF1D1E33),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Student Analysis: ${widget.username}'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF24D876)))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        Text('Connect Error: $_error', style: const TextStyle(color: Colors.white54)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadStudentData,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF24D876), foregroundColor: Colors.black),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadStudentData,
                    color: const Color(0xFF24D876),
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildProfileCard(),
                        const SizedBox(height: 25),
                        _buildSectionHeader("Placement Readiness"),
                        const SizedBox(height: 15),
                        _buildQuickStats(),
                        const SizedBox(height: 25),
                        if ((_data!['interview_history'] as List).isNotEmpty) ...[
                          _buildSectionHeader("Mock Interview Sessions"),
                          const SizedBox(height: 15),
                          _buildInterviewHistory(),
                          const SizedBox(height: 25),
                        ],
                        if ((_data!['category_stats'] as Map).isNotEmpty) ...[
                          _buildSectionHeader("Category Mastery"),
                          const SizedBox(height: 15),
                          _buildCategoryStats(),
                          const SizedBox(height: 25),
                        ],
                        if ((_data!['weak_areas'] as List).isNotEmpty) ...[
                          _buildSectionHeader("Critical Weak Areas"),
                          const SizedBox(height: 15),
                          _buildWeakAreas(),
                          const SizedBox(height: 25),
                        ],
                        _buildSectionHeader("Quiz Activity Log"),
                        const SizedBox(height: 15),
                        _buildQuizHistory(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF24D876).withOpacity(0.15), const Color(0xFF1D1E33)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF24D876).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF24D876).withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF24D876), width: 2),
            ),
            child: Center(
              child: Text(
                widget.username[0].toUpperCase(),
                style: const TextStyle(fontSize: 28, color: Color(0xFF24D876), fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _data!['student']['username'],
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Branch: ${_data!['student']['branch']}', style: const TextStyle(color: Colors.white54)),
                Text('Joined: ${_data!['student']['joined_date']}', style: const TextStyle(fontSize: 11, color: Colors.white24)),
              ],
            ),
          ),
          Column(
            children: [
              _buildLevelBadge("APT", _data!['student']['aptitude_level']),
              const SizedBox(height: 8),
              _buildLevelBadge("TECH", _data!['student']['technical_level']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelBadge(String label, int level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(level.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF24D876))),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMiniStat("STREAK", "${_data!['completion_last_7_days']}d", Icons.local_fire_department, Colors.orangeAccent),
            _buildMiniStat("ACCURACY", "${_calculateOverallAccuracy()}%", Icons.track_changes, Colors.blueAccent),
            _buildMiniStat("SESSION", "${(_data!['quiz_history'] as List).length}", Icons.assignment_outlined, Colors.purpleAccent),
          ],
        ),
      ),
    );
  }

  int _calculateOverallAccuracy() {
    final history = _data!['quiz_history'] as List;
    if (history.isEmpty) return 0;
    double sum = history.map((e) => (e['percentage'] as num).toDouble()).reduce((a, b) => a + b);
    return (sum / history.length).toInt();
  }

  Widget _buildMiniStat(String label, String val, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white30, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInterviewHistory() {
    final list = _data!['interview_history'] as List;
    return Column(
      children: list.map((session) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          onTap: () => _showInterviewDetail(session['id']),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.video_chat_outlined, color: Colors.purpleAccent),
          ),
          title: Text("Session #${session['id']}", style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Score: ${session['score']}/10 • ${session['confidence']}", style: const TextStyle(fontSize: 12, color: Colors.white38)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white24),
        ),
      )).toList(),
    );
  }

  Widget _buildCategoryStats() {
    final stats = _data!['category_stats'] as Map<String, dynamic>;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: stats.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
                    Text("${e.value['avg_score']}% AVG", style: const TextStyle(color: Color(0xFF24D876), fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (e.value['avg_score'] as num).toDouble() / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    color: const Color(0xFF24D876),
                  ),
                ),
                const SizedBox(height: 4),
                Text("${e.value['total_quizzes']} Quizzes Taken", style: const TextStyle(fontSize: 10, color: Colors.white24)),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildWeakAreas() {
    final areas = _data!['weak_areas'] as List;
    return Column(
      children: areas.map((area) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.priority_high_rounded, color: Colors.redAccent, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(area['area'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${area['attempts']} attempts', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                ],
              ),
            ),
            Text('${area['avg_score']}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 18)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildQuizHistory() {
    final history = _data!['quiz_history'] as List;
    if (history.isEmpty) return const Center(child: Text("No history available", style: TextStyle(color: Colors.white24)));
    
    return Column(
      children: history.take(15).map((q) {
        final double pct = (q['percentage'] as num).toDouble();
        final Color scoreColor = pct >= 80 ? const Color(0xFF24D876) : pct >= 50 ? Colors.orangeAccent : Colors.redAccent;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1E33),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.03)),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(color: scoreColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Center(child: Text("${pct.toInt()}%", style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 12))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q['category'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(q['area'], style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (q['confidence'] != null && q['confidence'].toString().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                      child: Text(q['confidence'], style: const TextStyle(fontSize: 9, color: Colors.white54)),
                    ),
                  const SizedBox(height: 4),
                  Text(_formatShortDate(q['date']), style: const TextStyle(color: Colors.white24, fontSize: 9)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showInterviewDetail(int sessionId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1D1E33),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => FutureBuilder<Map<String, dynamic>>(
          future: TeacherApiService.getInterviewSessionDetail(sessionId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
            
            final detail = snapshot.data!;
            final report = detail['detailed_report'] as List;
            
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),
                const Text("Session Analysis", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text("Overall Score: ${detail['score']}/10", style: const TextStyle(color: Color(0xFF24D876), fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 25),
                _buildReportSection("Behavioral Feedback", detail['behavioral_feedback'], Icons.face_retouching_natural_rounded),
                const SizedBox(height: 25),
                const Text("Technical Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 15),
                ...report.map((q) => Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Q: ${q['question']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 10),
                      Text("Feedback: ${q['feedback']}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text("Score: ${q['score']}/10", style: const TextStyle(color: Color(0xFF24D876), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )).toList(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildReportSection(String title, String? content, IconData icon) {
    if (content == null || content.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white38, size: 18),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white38, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16)),
          child: Text(content, style: const TextStyle(height: 1.5, fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: const Color(0xFF24D876), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13, letterSpacing: 1.1)),
      ],
    );
  }

  String _formatShortDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return "${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
