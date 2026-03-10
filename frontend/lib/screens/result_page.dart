import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';

class ResultPage extends StatelessWidget {
  final Map<String, dynamic> result;

  const ResultPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    // Extracting data from result JSON
    final double overallScore = (result['overall_score'] ?? 0.0).toDouble();
    final double contentScore = (result['content_score'] ?? 0.0).toDouble();
    final double communicationScore = (result['communication_score'] ?? 0.0).toDouble();
    final double cameraScore = (result['camera_score'] ?? 0.0).toDouble();
    
    final String transcript = result['transcript'] ?? "";
    final String improvedAnswer = result['improved_answer'] ?? "";
    final String idealAnswer = result['ideal_answer'] ?? "";
    final String strategyNote = result['strategy_note'] ?? "";
    final String feedback = result['feedback'] ?? "";

    Color getScoreColor(double score) {
      if (score >= 7.5) return Colors.greenAccent;
      if (score >= 5.0) return Colors.yellowAccent;
      return Colors.redAccent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Evaluation",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Readiness Gauge
            Center(
              child: Column(
                children: [
                  CircularPercentIndicator(
                    radius: 80.0,
                    lineWidth: 12.0,
                    percent: overallScore / 10.0,
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          overallScore.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "SCORE",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white60,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    circularStrokeCap: CircularStrokeCap.round,
                    backgroundColor: Colors.white10,
                    progressColor: getScoreColor(overallScore),
                    animation: true,
                    animationDuration: 1500,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "FINAL SCORE",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.cyanAccent,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),


            const SizedBox(height: 32),

            // The Three Pillars
            Row(
              children: [
                Expanded(
                  child: _buildPillarCard(
                    "Content",
                    contentScore.toStringAsFixed(1),
                    Icons.psychology,
                    Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPillarCard(
                    "Communication",
                    communicationScore.toStringAsFixed(1),
                    Icons.forum,
                    Colors.purpleAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPillarCard(
                    "Visual",
                    cameraScore.toStringAsFixed(1),
                    Icons.visibility,
                    Colors.orangeAccent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            const SizedBox(height: 32),

            // Transcript Highlight View
            Text(
              "Transcript Analysis",
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161625),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _buildHighlightedTranscript(transcript),
            ),

            const SizedBox(height: 32),

            // Comparison Section
            Text(
              "Response Comparison",
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildComparisonBox("YOUR RESPONSE", transcript, Colors.white70),
                const SizedBox(height: 16),
                _buildComparisonBox("IMPROVED ANSWER", improvedAnswer, Colors.cyanAccent.withOpacity(0.8)),
                const SizedBox(height: 16),
                _buildComparisonBox("EXPERT IDEAL ANSWER", idealAnswer, Colors.greenAccent.withOpacity(0.8)),
                if (strategyNote.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.psychology, color: Colors.cyanAccent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "STRATEGY: $strategyNote",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 32),

            // Actionable Feedback
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A2980), Color(0xFF26D0CE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "AI FEEDBACK",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    feedback,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh, color: Colors.black),
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                label: const Text(
                  "Try Another Topic",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarCard(String title, String score, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161625),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            score,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white60,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBox(String label, String content, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.cyanAccent,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Text(
            content.isEmpty ? "No data available." : content,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: textColor,
              height: 1.6,
              fontStyle: label.contains("YOUR") ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightedTranscript(String text) {
    final fillers = ['um', 'uh', 'like', 'actually', 'basically'];
    final words = text.split(' ');
    
    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.6),
        children: words.map((word) {
          final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
          final isFiller = fillers.contains(cleanWord);
          
          return TextSpan(
            text: "$word ",
            style: TextStyle(
              backgroundColor: isFiller ? Colors.redAccent.withOpacity(0.3) : null,
              color: isFiller ? Colors.redAccent : null,
              fontWeight: isFiller ? FontWeight.bold : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}




