import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileUiPrefs {
  const ProfileUiPrefs({
    required this.schoolName,
    required this.listeningGradeLabel,
    required this.readingGradeLabel,
    required this.ageLabel,
    required this.birthDate,
    this.avatarImagePath,
  });

  final String schoolName;
  final String listeningGradeLabel;
  final String readingGradeLabel;
  final String ageLabel;
  final String birthDate;
  final String? avatarImagePath;

  ProfileUiPrefs copyWith({
    String? schoolName,
    String? listeningGradeLabel,
    String? readingGradeLabel,
    String? ageLabel,
    String? birthDate,
    String? avatarImagePath,
    bool clearAvatarImagePath = false,
  }) {
    return ProfileUiPrefs(
      schoolName: schoolName ?? this.schoolName,
      listeningGradeLabel: listeningGradeLabel ?? this.listeningGradeLabel,
      readingGradeLabel: readingGradeLabel ?? this.readingGradeLabel,
      ageLabel: ageLabel ?? this.ageLabel,
      birthDate: birthDate ?? this.birthDate,
      avatarImagePath: clearAvatarImagePath
          ? null
          : (avatarImagePath ?? this.avatarImagePath),
    );
  }
}

final profileUiPrefsProvider = StateProvider<ProfileUiPrefs>((Ref ref) {
  return const ProfileUiPrefs(
    schoolName: '학교 미설정',
    listeningGradeLabel: '고1',
    readingGradeLabel: '고1',
    ageLabel: '고1',
    birthDate: '',
    avatarImagePath: null,
  );
});
