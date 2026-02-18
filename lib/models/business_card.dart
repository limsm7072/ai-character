class BusinessCard {
  String name;
  String company;
  String position;
  String phone;
  String email;
  String bio;
  String country;
  String province; // 도/광역시
  String city;     // 시/구
  String gender;   // '남', '여', ''
  String birthYear; // e.g. '1990'
  String photoPath; // 로컬 사진 경로
  int theme; // 0=미니멀화이트, 1=다크, 2=그라데이션, 3=파스텔

  // 공개 여부 토글 (이름은 항상 공개)
  bool showCompany;
  bool showPosition;
  bool showPhone;
  bool showEmail;
  bool showBio;
  bool showLocation;
  bool showGender;
  bool showBirthYear;
  bool showPhoto;

  BusinessCard({
    this.name = '',
    this.company = '',
    this.position = '',
    this.phone = '',
    this.email = '',
    this.bio = '',
    this.country = '',
    this.province = '',
    this.city = '',
    this.gender = '',
    this.birthYear = '',
    this.photoPath = '',
    this.theme = 0,
    this.showCompany = true,
    this.showPosition = true,
    this.showPhone = true,
    this.showEmail = true,
    this.showBio = true,
    this.showLocation = true,
    this.showGender = true,
    this.showBirthYear = true,
    this.showPhoto = true,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'company': company,
    'position': position,
    'phone': phone,
    'email': email,
    'bio': bio,
    'country': country,
    'province': province,
    'city': city,
    'gender': gender,
    'birthYear': birthYear,
    'photoPath': photoPath,
    'theme': theme,
    'showCompany': showCompany,
    'showPosition': showPosition,
    'showPhone': showPhone,
    'showEmail': showEmail,
    'showBio': showBio,
    'showLocation': showLocation,
    'showGender': showGender,
    'showBirthYear': showBirthYear,
    'showPhoto': showPhoto,
  };

  factory BusinessCard.fromJson(Map<String, dynamic> json) => BusinessCard(
    name: json['name'] as String? ?? '',
    company: json['company'] as String? ?? '',
    position: json['position'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    bio: json['bio'] as String? ?? '',
    country: json['country'] as String? ?? '',
    province: json['province'] as String? ?? '',
    city: json['city'] as String? ?? '',
    gender: json['gender'] as String? ?? '',
    birthYear: json['birthYear'] as String? ?? '',
    photoPath: json['photoPath'] as String? ?? '',
    theme: json['theme'] as int? ?? 0,
    showCompany: json['showCompany'] as bool? ?? true,
    showPosition: json['showPosition'] as bool? ?? true,
    showPhone: json['showPhone'] as bool? ?? true,
    showEmail: json['showEmail'] as bool? ?? true,
    showBio: json['showBio'] as bool? ?? true,
    showLocation: json['showLocation'] as bool? ?? true,
    showGender: json['showGender'] as bool? ?? true,
    showBirthYear: json['showBirthYear'] as bool? ?? true,
    showPhoto: json['showPhoto'] as bool? ?? true,
  );

  String get locationText {
    final parts = <String>[];
    if (city.isNotEmpty) parts.add(city);
    if (province.isNotEmpty) parts.add(province);
    if (country.isNotEmpty) parts.add(country);
    return parts.join(', ');
  }

  String toVCard() {
    final buf = StringBuffer();
    buf.writeln('BEGIN:VCARD');
    buf.writeln('VERSION:3.0');
    buf.writeln('FN:$name');
    if (showCompany && company.isNotEmpty) buf.writeln('ORG:$company');
    if (showPosition && position.isNotEmpty) buf.writeln('TITLE:$position');
    if (showPhone && phone.isNotEmpty) buf.writeln('TEL:$phone');
    if (showEmail && email.isNotEmpty) buf.writeln('EMAIL:$email');
    if (showLocation && locationText.isNotEmpty) buf.writeln('ADR:;;$city;$province;;$country');
    if (showBio && bio.isNotEmpty) buf.writeln('NOTE:$bio');
    buf.writeln('END:VCARD');
    return buf.toString();
  }

  String toShareText() {
    final parts = <String>[];
    if (name.isNotEmpty) parts.add(name);
    final pos = showPosition ? position : '';
    final comp = showCompany ? company : '';
    if (pos.isNotEmpty && comp.isNotEmpty) {
      parts.add('$pos | $comp');
    } else if (comp.isNotEmpty) {
      parts.add(comp);
    } else if (pos.isNotEmpty) {
      parts.add(pos);
    }
    if (showLocation && locationText.isNotEmpty) parts.add(locationText);
    if (showPhone && phone.isNotEmpty) parts.add('Tel: $phone');
    if (showEmail && email.isNotEmpty) parts.add('Email: $email');
    if (showGender && gender.isNotEmpty) parts.add('성별: $gender');
    if (showBirthYear && birthYear.isNotEmpty) parts.add('${birthYear}년생');
    if (showBio && bio.isNotEmpty) parts.add(bio);
    return parts.join('\n');
  }

  bool get isEmpty => name.isEmpty && company.isEmpty && phone.isEmpty && email.isEmpty;
}
