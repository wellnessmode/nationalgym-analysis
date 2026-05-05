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
              icon: Icons.inbox_outlined,
              title: '대표가 전달한 업무 확인',
              body: '업무 탭에 "대표 전달" 카드로 표시됩니다. 카드를 탭해 상세에서 내용을 확인하고 작업을 시작하세요.',
            ),
            _Item(
              icon: Icons.add_task,
              title: '본인 업무 직접 추가',
              body: '업무 탭 우하단 + 버튼 → 제목·기한·우선순위 입력. 본인 지점에 자동 배정됩니다.',
            ),
            _Item(
              icon: Icons.flag_circle,
              title: 'D-day · 우선순위 보기',
              body: '카드 우상단의 빨강(경과)·주황(임박)·회색(여유) 뱃지로 마감 상태를 한눈에. 우선순위는 chip으로 표시.',
            ),
            _Item(
              icon: Icons.timelapse,
              title: '상태 / 메모 / 진행기록',
              body: '카드 탭 → 상세 화면에서 상태(대기·진행 중·완료·보류) 변경. 메모로 본인 작업 기록, 댓글로 진행 사항 공유.',
            ),
            _Item(
              icon: Icons.attach_file,
              title: '파일·사진 첨부',
              body: '업무 상세 → "첨부파일" 섹션 우측 "추가" 버튼 → 갤러리 / 카메라 / PDF·워드·엑셀 등 선택. 모바일은 카메라가 바로 열립니다.',
            ),
            _Item(
              icon: Icons.delete_outline,
              title: '업무 삭제',
              body: '본인이 만든 업무는 상세 화면 우상단 휴지통으로 삭제. 댓글·첨부파일도 함께 정리됩니다.',
            ),
          ]),

          Section(title: '회의록', children: [
            _Item(
              icon: Icons.add_comment_outlined,
              title: '회의록 만들기',
              body: '회의록 탭 우하단 + 버튼 → 주제·회의일자·참석자(체크) 입력. 회의 전이면 "어젠다", 회의 후 정리 끝나면 "완료"로 저장.',
            ),
            _Item(
              icon: Icons.mic,
              title: '회의 음성 자동 받아쓰기',
              body: '주제 입력 후 "인식 시작" → 마이크 권한 허용 → 회의 진행. 본문에 실시간 텍스트 누적, "정지"로 종료. iOS Safari는 화면 켜둔 채로.',
            ),
            _Item(
              icon: Icons.auto_awesome,
              title: 'AI로 회의록 정리',
              body: '받아쓰기 끝나면 "AI로 회의록 정리" 골드 버튼 → 본문이 정돈된 회의록으로 변환되고 후속조치가 자동 채워집니다.',
            ),
            _Item(
              icon: Icons.attach_file,
              title: '파일·사진 첨부',
              body: '회의록 상세 → "첨부파일" 섹션에서 사진·PDF·엑셀 등 추가. 회의 자료를 한곳에 모아두세요.',
            ),
            _Item(
              icon: Icons.edit_note,
              title: '편집 · 삭제',
              body: '본인이 작성한 회의록은 우상단 연필로 편집, 휴지통으로 삭제. 어젠다는 회의 후 "완료로 저장"으로 전환.',
            ),
          ]),

          Section(title: '메모장', children: [
            _Item(
              icon: Icons.sticky_note_2_outlined,
              title: '메모 여러 개 만들기',
              body: '메모장 탭 우하단 "새 메모" 버튼으로 원하는 만큼 추가. iOS 메모처럼 첫 줄이 자동 제목이 됩니다.',
            ),
            _Item(
              icon: Icons.lock_outline,
              title: '기본은 본인만',
              body: '메모는 기본적으로 비공개. 본인만 볼 수 있고 자동 저장됩니다.',
            ),
            _Item(
              icon: Icons.group_outlined,
              title: '메모 단위로 공유',
              body: '메모를 열고 우측 상단 자물쇠 → 공유 대상 1명 선택. 공유한 메모는 상대방의 "공유된 메모" 섹션에 나타나며 둘 다 편집 가능.',
            ),
            _Item(
              icon: Icons.save_outlined,
              title: '자동 저장 · 삭제',
              body: '입력 멈춘 후 약 1초 뒤 자동 저장. 더 이상 필요 없으면 우상단 휴지통으로 삭제.',
            ),
          ]),

          Section(title: '알림', children: [
            _Item(
              icon: Icons.notifications_active,
              title: '푸시 알림 켜기',
              body: '설정 탭 → "푸시 알림 활성화" → 권한 허용. iOS는 Safari 공유 → "홈 화면에 추가" 후 홈 아이콘으로 진입해야 동작합니다.',
            ),
            _Item(
              icon: Icons.alarm,
              title: '받게 되는 알림',
              body: '대표가 본인에게 업무 전달, 댓글, 업무 완료, 회의록 변경. 매일 오전 9시에 마감 임박(D-1·당일)·경과 업무 자동 알림.',
            ),
            _Item(
              icon: Icons.inbox,
              title: '알림함',
              body: '상단 종 아이콘 → 받은 알림 목록. 미읽음은 파란 점, "모두 읽음"으로 일괄 처리.',
            ),
          ]),

          Section(title: '계정 · 보안', children: [
            _Item(
              icon: Icons.lock,
              title: '비밀번호 변경',
              body: '첫 로그인 후 설정 → 비밀번호 변경에서 즉시 본인이 기억할 비번으로 바꾸세요. (8자 이상)',
            ),
            _Item(
              icon: Icons.logout,
              title: '로그아웃',
              body: '다른 사람과 같은 기기를 쓰면 반드시 로그아웃. 푸시 알림 토큰도 함께 정리되어 다른 사람 알림이 안 오게 됩니다.',
            ),
          ]),

          SizedBox(height: Tokens.s24),
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
          const Expanded(
            child: Text(
              'National Gym Workspace',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
        const SizedBox(height: Tokens.s8),
        Text(
          '대표가 전달한 업무 처리, 회의록 음성 자동 정리, 본인·공유 메모 작성, 푸시 알림. 아래 항목별 안내를 참고하세요.',
          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13, height: 1.55),
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
