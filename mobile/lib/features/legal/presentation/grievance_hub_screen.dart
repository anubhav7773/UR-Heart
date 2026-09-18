import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/network/api_client.dart';

class GrievanceHubScreen extends StatefulWidget {
  const GrievanceHubScreen({super.key});

  @override
  State<GrievanceHubScreen> createState() => _GrievanceHubScreenState();
}

class _GrievanceHubScreenState extends State<GrievanceHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _officerInfo;
  List<dynamic> _myTickets = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = createApiClient();
      
      final results = await Future.wait([
        dio.get('/api/v1/legal/officer-details'),
        dio.get('/api/v1/legal/grievance/my-tickets', options: Options(headers: {'Authorization': 'Bearer $token'})),
      ]);

      if (mounted) {
        setState(() {
          _officerInfo = results[0].data;
          _myTickets = results[1].data;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFileGrievanceDialog() {
    String selectedCategory = "harassment_abuse";
    final descController = TextEditingController();

    final Map<String, String> categories = {
      "harassment_abuse": "Harassment / Abusive Behavior",
      "ncii_nudity": "NCII / Nudity / Explicit Media",
      "impersonation_fake": "Fake Profile / Impersonation",
      "underage_minor": "Underage User (< 18 Years)",
      "financial_scam": "Scam / Commercial Solicitation",
      "data_privacy_dpdp": "DPDP Data Erasure / Privacy Issue",
      "other": "Other Legal Violation"
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16161D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalStateCtx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("File Formal Grievance", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("Mandatory redressal under Rule 3(2) IT Rules 2021", style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 12)),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                dropdownColor: const Color(0xFF22222C),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: "Violation Category",
                  labelStyle: const TextStyle(color: Color(0xFFA0A0B2)),
                  filled: true,
                  fillColor: const Color(0xFF22222C),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: categories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (val) => setModalState(() => selectedCategory = val!),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: descController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Provide factual incident details, usernames, or dates...",
                  hintStyle: const TextStyle(color: Color(0xFF636375)),
                  filled: true,
                  fillColor: const Color(0xFF22222C),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2E63),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final desc = descController.text.trim();
                    if (desc.isEmpty) return;
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);

                    try {
                      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
                      final dio = createApiClient();
                      final formData = FormData.fromMap({
                        "category": selectedCategory,
                        "description": desc,
                      });

                      final res = await dio.post(
                        '/api/v1/legal/grievance/file',
                        data: formData,
                        options: Options(headers: {'Authorization': 'Bearer $token'}),
                      );

                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text("✓ Ticket Filed: ${res.data['ticket_number']}. Acknowledgment SLA: 24h."),
                          backgroundColor: const Color(0xFF06D6A0),
                        ),
                      );
                      _loadData();
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text("Submission failed: $e"), backgroundColor: const Color(0xFFFF334B)),
                      );
                    }
                  },
                  child: const Text("Submit Grievance Ticket", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPolicyViewer(String policyType, String title) async {
    final dio = createApiClient();
    final res = await dio.get('/api/v1/legal/policies/$policyType');
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16161D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(res.data['version'] ?? '', style: const TextStyle(color: Color(0xFF08D9D6), fontSize: 12)),
              const Divider(color: Colors.white24, height: 24),
              Text(res.data['content'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color canvasBg = Color(0xFF0A0A0D);
    const Color cardSurface = Color(0xFF16161D);

    return Scaffold(
      backgroundColor: canvasBg,
      appBar: AppBar(
        backgroundColor: canvasBg,
        elevation: 0,
        title: const Text("Legal & Grievance Redressal", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF2E63),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFFA0A0B2),
          tabs: const [
            Tab(text: "Grievance Officer & SLA"),
            Tab(text: "My Filed Tickets"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showFileGrievanceDialog,
        backgroundColor: const Color(0xFFFF2E63),
        icon: const Icon(Icons.report_problem_outlined, color: Colors.white),
        label: const Text("File Grievance", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF2E63)))
          : TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Statutory Compliance Officer & Legal Documents
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_officerInfo != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFFD166).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.gavel_rounded, color: Color(0xFFFFD166), size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  _officerInfo!['designation'] ?? '',
                                  style: const TextStyle(color: Color(0xFFFFD166), fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text("Name: ${_officerInfo!['officer_name'] ?? ''}", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Entity: ${_officerInfo!['entity_name'] ?? ''}", style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 13)),
                            Text("Email: ${_officerInfo!['email'] ?? ''}", style: const TextStyle(color: Color(0xFF08D9D6), fontSize: 13)),
                            const SizedBox(height: 4),
                            Text("Jurisdiction: ${_officerInfo!['physical_address'] ?? ''}", style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 12)),
                            const Divider(color: Colors.white12, height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Acknowledgment SLA", style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 11)),
                                    Text(_officerInfo!['acknowledgement_sla'] ?? '', style: const TextStyle(color: Color(0xFF06D6A0), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text("Resolution SLA", style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 11)),
                                    Text(_officerInfo!['resolution_sla'] ?? '', style: const TextStyle(color: Color(0xFF06D6A0), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),

                    const Text("Statutory Charters & Policies", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    _buildPolicyTile("DPDP Privacy Notice & Data Charter", () => _showPolicyViewer("privacy", "DPDP Privacy Notice")),
                    _buildPolicyTile("End User License Agreement (EULA)", () => _showPolicyViewer("terms", "Terms of Service & EULA")),
                    _buildPolicyTile("Zero Harassment & Community Guidelines", () => _showPolicyViewer("community_guidelines", "Community Guidelines")),
                  ],
                ),

                // TAB 2: User's Filed Tickets Tracker
                _myTickets.isEmpty
                    ? const Center(
                        child: Text("No grievance tickets filed.", style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 13)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _myTickets.length,
                        itemBuilder: (ctx, idx) {
                          final t = _myTickets[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(t['ticket_number'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: t['status'] == 'resolved' ? const Color(0xFF06D6A0).withValues(alpha: 0.2) : const Color(0xFFFFD166).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        t['status'].toString().toUpperCase(),
                                        style: TextStyle(
                                          color: t['status'] == 'resolved' ? const Color(0xFF06D6A0) : const Color(0xFFFFD166),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text("Category: ${t['category'] ?? ''}", style: const TextStyle(color: Color(0xFF08D9D6), fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(t['description'] ?? '', style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 13)),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
    );
  }

  Widget _buildPolicyTile(String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF16161D),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
          trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFFA0A0B2), size: 14),
          onTap: onTap,
        ),
      ),
    );
  }
}
