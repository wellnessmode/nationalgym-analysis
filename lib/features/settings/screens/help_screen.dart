import 'package:flutter/material.dart';
import '../../../core/tokens.dart';
import '../../../shared/widgets/section.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사용법')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Tokens.s32),
        children: const [
          _Intro(),
          Section(title: '업무', children: [
            _Item(
              icon: Icons.task_alt,
              title: '대표가 매니저에게 지시 발행',
              body: '업무 탭 우하단 + 버튼 또는 빈 상태의 가운데 버튼 → 지점·담당자 선택 → 제목·기한·우선순위 → 발행. 담당 매니저에게 즉시 푸시 알림.',
            ),
            _Item(
              icon: Icons.assignment_ind,
              title: '매니저 본인 업무 추가',
              body: '매니저는 지시받지 않은 본인 업무를 자체적으로 추가 가능. 본인 지점에 자동 배정.',
            ),
            _Item(
              icon: Icons.filter_list,
              title: '필터',
              body: '전체 / 대표 지시 / 내 업무 (본인이 담당자 또는 요청자) / 완료함. 대표는 추가로 1·2·3호점 별 필터.',
            ),
            _Item(
              icon: Icons.flag_circle,
              title: 'D-day · 우선순위',
              body: '마감 경과 빨강, D-day/D-1 주황, 그 외 회색. 카드 우상단에 표시.',
            ),
            _Item(
              icon: Icons.timelapse,
              title: '상태 변경 · 메모 · 진행기록',
              body: '카드 클릭 → 상세 → 상태 chip (대기/진행 중/완료/보류). 메모 입력 후 "저장". 댓글로 진행 사항 기록.',
            ),
          ]),

          Section(title: '회의록', children: [
            _Item(
              icon: Icons.mic,
              title: '회의 음성 자동 받아쓰기 (무료)',
              body: '회의록 작성 화면 → 주제 입력 → "인식 시작" 버튼 → 마이크 권한 허용 → 회의 진행. 본문에 실시간 텍스트 누적. "정지"로 종료.',
            ),
            _Item(
              icon: Icons.auto_awesome,
              title: 'AI로 회의록 정리 (무료)',
              body: '받아쓰기 후 "AI로 회의록 정리" 골드 버튼 → 1~3초 후 본문이 마크다운 회의록으로 정리되고 후속조치 체크리스트가 자동 채워짐.',
            ),
            _Item(
              icon: Icons.edit_note,
              title: '어젠다 / 완료',
              body: '회의 전 미리 어젠다(draft)로 저장 → 회의 후 "완료" 상태로 전환. 매니저가 작성한 모든 회의록은 대표에게 자동 알림.',
            ),
            _Item(
              icon: Icons.warning_amber_rounded,
              title: '주의',
              body: 'iOS Safari 음성 인식은 화면이 꺼지거나 다른 앱 전환 시 멈춥니다. 회의 중 화면 켜둔 채로 진행하세요.',
            ),
          ]),

          Section(title: '알림', children: [
            _Item(
              icon: Icons.notifications_active,
              title: '푸시 알림 켜기',
              body: '설정 탭 → "푸시 알림" 활성화 버튼 → 권한 허용. iOS는 반드시 Safari 공유 → "홈 화면에 추가" 후 홈 아이콘으로 진입한 standalone 모드여야 동작.',
            ),
            _Item(
              icon: Icons.alarm,
              title: '자동 알림 종류',
              body: '대표 지시 발행, 댓글 추가, 업무 완료, 회의록 어젠다/완료. 매일 오전 9시 마감 임박(D-1·당일)·경과 업무 자동 알림.',
            ),
            _Item(
              icon: Icons.inbox,
              title: '알림함',
              body: '상단 종 아이콘 → 받은 알림 목록. 미읽음은 파란 점 표시. "모두 읽음"으로 한 번에 처리.',
            ),
          ]),

          Section(title: '계정 · 보안', children: [
            _Item(
              icon: Icons.lock,
              title: '비밀번호 변경',
              body: '설정 탭 → "비밀번호 변경" → 새 비번 (8자 이상) → 변경하기. 매니저들은 첫 로그인 후 즉시 변경 권장.',
            ),
            _Item(
              icon: Icons.logout,
              title: '로그아웃',
              body: '다른 사람과 같은 기기 사용 시 반드시 로그아웃. 자동 로그아웃 시 푸시 알림 토큰도 함께 정리됨.',
            ),
          ]),

          SizedBox(height: Tokens.s32),
          _Footer(),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s24, Tokens.s16, 0),
      padding: const EdgeInsets.all(Tokens.s20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.r20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Tokens.navy900, Tokens.navy700],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.menu_book, color: Tokens.gold500, size: 22),
          const SizedBox(width: Tokens.s8),
          const Text(
            'NATIONAL GYM Operations 사용법',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ]),
        const SizedBox(height: Tokens.s8),
        Text(
          '업무 지시·진행 관리, 회의록 음성 자동 정리, 푸시 알림이 기본 기능입니다. 아래 항목별 안내 참고.',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.5),
        ),
      ]),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Item({required this.icon, required this.title, required this.body});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Tokens.s16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: Tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(Tokens.r8),
          ),
          child: Icon(icon, size: 16, color: Tokens.navy900),
        ),
        const SizedBox(width: Tokens.s12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Tokens.ts14.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(body, style: Tokens.ts13.copyWith(color: Tokens.textMuted, height: 1.55)),
          ]),
        ),
      ]),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Tokens.s16),
      child: Center(
        child: Text(
          '문의는 대표 (최현승)에게',
          style: Tokens.ts12.copyWith(color: Tokens.textFaint),
        ),
      ),
    );
  }
}
