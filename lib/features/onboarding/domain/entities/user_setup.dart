class UserSetup {
  final String username;
  final String premiumCode;
  final String downloadDir;
  final bool isCompleted;

  const UserSetup({
    this.username = '',
    this.premiumCode = '',
    this.downloadDir = '',
    this.isCompleted = false,
  });

  UserSetup copyWith({
    String? username,
    String? premiumCode,
    String? downloadDir,
    bool? isCompleted,
  }) {
    return UserSetup(
      username: username ?? this.username,
      premiumCode: premiumCode ?? this.premiumCode,
      downloadDir: downloadDir ?? this.downloadDir,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
