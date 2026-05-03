/// 지점 풀네임 → 짧은 라벨.
///   내셔널짐 PT 용산점        → 1호점
///   내셔널짐 PT 서초점        → 2호점
///   내셔널짐 피티앤골프 스튜디오 → 3호점
/// 매칭 안 되면 마지막 단어로 폴백.
String shortBranchLabel(String fullName) {
  final n = fullName;
  if (n.contains('용산')) return '1호점';
  if (n.contains('서초')) return '2호점';
  if (n.contains('피티앤골프') || n.contains('스튜디오')) return '3호점';
  final parts = n.split(' ');
  return parts.isEmpty ? n : parts.last;
}
