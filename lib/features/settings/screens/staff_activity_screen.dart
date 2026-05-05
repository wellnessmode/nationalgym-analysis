import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tokens.dart';
import '../../../services/supabase_client.dart';
import '../../../shared/providers/auth_provider.dart';

/// 대표 (ceo@nationalgym.kr) 전용 — 직원 활동 로그.
/// Supabase RPC `get_staff_activity` 호출. 함수 내부에서 호출자 이메일 검증.
class StaffActivityScreen extends ConsumerStatefulWidget {
  const StaffActivityScreen({super.key});

  @override
  ConsumerState<StaffActivityScreen> createState() => _StaffActivityScreenState();
}

class _StaffActivityScreenState extends ConsumerState<StaffActivityScreen> {
  late Future<List<_StaffActivity>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_StaffActivity>> _load() async {
    final res = await supabase.rpc('get_staff_activity');
    return (res as List).map((j) => _StaffActivity.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (me.email != 'ceo@nationalgym.kr') {
      return const Scaffold(
        body: Center(child: Text('대표만 접근할 수 있습니다')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('직원 활동 로그')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<_StaffActivity>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(Tokens.s24),
                  child: Text('에러: ${snap.error}',
                      style: Tokens.ts13.copyWith(color: Tokens.danger)),
                ),
              );
            }
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return Center(
                child: Text('표시할 직원이 없습니다',
                    style: Tokens.ts13.copyWith(color: Tokens.textMuted)),
              );
            }
            return ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.s16, vertical: Tokens.s12),
              children: [
                Container(
                  padding: const EdgeInsets.all(Tokens.s12),
                  decoration: BoxDecoration(
                    color: Tokens.gold500.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(Tokens.r12),
                    border: Border.all(color: Tokens.gold500.withOpacity(0.25)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline, size: 16, color: Tokens.gold600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '직원별 마지막 로그인, 메모/업무/회의록 작성 통계입니다. 대표만 볼 수 있어요.',
                        style: Tokens.ts11.copyWith(color: Tokens.text, height: 1.5),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: Tokens.s12),
                for (final s in list) _StaffCard(activity: s),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StaffActivity {
  final String userId;
  final String name;
  final String email;
  final String role;
  final DateTime? lastSignInAt;
  final DateTime? accountCreatedAt;
  final int notesCount;
  final DateTime? lastNoteEdit;
  final int tasksTotal;
  final int tasksDone;
  final DateTime? lastTaskUpdate;
  final int meetingsTotal;
  final DateTime? lastMeetingUpdate;
  final DateTime? lastActivity;

  _StaffActivity({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.lastSignInAt,
    required this.accountCreatedAt,
    required this.notesCount,
    required this.lastNoteEdit,
    required this.tasksTotal,
    required this.tasksDone,
    required this.lastTaskUpdate,
    required this.meetingsTotal,
    required this.lastMeetingUpdate,
    required this.lastActivity,
  });

  static DateTime? _t(dynamic v) => v == null ? null : DateTime.parse(v as String);
  static int _i(dynamic v) => v == null ? 0 : (v as num).toInt();

  factory _StaffActivity.fromJson(Map<String, dynamic> j) => _StaffActivity(
        userId: j['user_id'] as String,
        name: j['name'] as String? ?? '?',
        email: j['email'] as String? ?? '',
        role: j['role'] as String? ?? 'manager',
        lastSignInAt: _t(j['last_sign_in_at']),
        accountCreatedAt: _t(j['account_created_at']),
        notesCount: _i(j['notes_count']),
        lastNoteEdit: _t(j['last_note_edit']),
        tasksTotal: _i(j['tasks_total']),
        tasksDone: _i(j['tasks_done']),
        lastTaskUpdate: _t(j['last_task_update']),
        meetingsTotal: _i(j['meetings_total']),
        lastMeetingUpdate: _t(j['last_meeting_update']),
        lastActivity: _t(j['last_activity']),
      );
}

class _StaffCard extends StatelessWidget {
  final _StaffActivity activity;
  const _StaffCard({required this.activity});

  String _rel(DateTime? t) {
    if (t == null) return '없음';
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 1) return '방금';
    if (d.inMinutes < 60) return '${d.inMinutes}분 전';
    if (d.inHours < 24) return '${d.inHours}시간 전';
    if (d.inDays < 7) return '${d.inDays}일 전';
    return DateFormat('MM-dd HH:mm').format(t.toLocal());
  }

  String _full(DateTime? t) =>
      t == null ? '-' : DateFormat('yyyy-MM-dd HH:mm').format(t.toLocal());

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.s10),
      padding: const EdgeInsets.all(Tokens.s14),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.r12),
        border: Border.all(color: Tokens.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(
              color: Tokens.navy900,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              activity.name.isNotEmpty ? activity.name.characters.first : '?',
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: Tokens.s10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(activity.name,
                  style: Tokens.ts15.copyWith(fontWeight: FontWeight.w700)),
              Text(activity.email,
                  style: Tokens.ts11.copyWith(color: Tokens.textMuted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _activityColor(activity.lastActivity).withOpacity(0.13),
              borderRadius: BorderRadius.circular(Tokens.r999),
            ),
            child: Text(
              _rel(activity.lastActivity),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _activityColor(activity.lastActivity)),
            ),
          ),
        ]),
        const Divider(height: Tokens.s20),
        _Row(label: '마지막 로그인', value: _full(activity.lastSignInAt)),
        _Row(
          label: '메모',
          value: '${activity.notesCount}개 · 마지막 ${_rel(activity.lastNoteEdit)}',
        ),
        _Row(
          label: '담당 업무',
          value:
              '${activity.tasksTotal}개 (완료 ${activity.tasksDone}) · 마지막 ${_rel(activity.lastTaskUpdate)}',
        ),
        _Row(
          label: '회의록 작성',
          value:
              '${activity.meetingsTotal}개 · 마지막 ${_rel(activity.lastMeetingUpdate)}',
        ),
        _Row(label: '계정 생성', value: _full(activity.accountCreatedAt)),
      ]),
    );
  }

  Color _activityColor(DateTime? t) {
    if (t == null) return Tokens.textFaint;
    final d = DateTime.now().difference(t.toLocal());
    if (d.inHours < 24) return Tokens.success;
    if (d.inDays < 7) return Tokens.gold600;
    return Tokens.textMuted;
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 88,
          child: Text(label,
              style: Tokens.ts12.copyWith(color: Tokens.textMuted)),
        ),
        Expanded(
          child: Text(value,
              style: Tokens.ts12.copyWith(fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
