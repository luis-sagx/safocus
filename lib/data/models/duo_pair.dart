class DuoPair {
  final String myCode;
  final String? partnerCode;
  final String? partnerName;
  final int sharedStreakDays;
  final DateTime? lastBothCheckedIn;
  final bool myCheckedInToday;

  const DuoPair({
    required this.myCode,
    this.partnerCode,
    this.partnerName,
    this.sharedStreakDays = 0,
    this.lastBothCheckedIn,
    this.myCheckedInToday = false,
  });

  bool get hasPaired => partnerCode != null;

  DuoPair copyWith({
    String? partnerCode,
    String? partnerName,
    int? sharedStreakDays,
    DateTime? lastBothCheckedIn,
    bool? myCheckedInToday,
  }) => DuoPair(
    myCode: myCode,
    partnerCode: partnerCode ?? this.partnerCode,
    partnerName: partnerName ?? this.partnerName,
    sharedStreakDays: sharedStreakDays ?? this.sharedStreakDays,
    lastBothCheckedIn: lastBothCheckedIn ?? this.lastBothCheckedIn,
    myCheckedInToday: myCheckedInToday ?? this.myCheckedInToday,
  );

  Map<String, dynamic> toJson() => {
    'myCode': myCode,
    'partnerCode': partnerCode,
    'partnerName': partnerName,
    'sharedStreakDays': sharedStreakDays,
    'lastBothCheckedIn': lastBothCheckedIn?.millisecondsSinceEpoch,
    'myCheckedInToday': myCheckedInToday,
  };

  factory DuoPair.fromJson(Map<String, dynamic> json) => DuoPair(
    myCode: json['myCode'] as String,
    partnerCode: json['partnerCode'] as String?,
    partnerName: json['partnerName'] as String?,
    sharedStreakDays: json['sharedStreakDays'] as int? ?? 0,
    lastBothCheckedIn: json['lastBothCheckedIn'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['lastBothCheckedIn'] as int)
        : null,
    myCheckedInToday: json['myCheckedInToday'] as bool? ?? false,
  );
}
