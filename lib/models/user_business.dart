class UserBusiness {
  const UserBusiness({
    this.logo,
    this.company,
    this.document,
    this.email,
    this.phone,
    this.address,
    this.paymentInfo,
    this.extraNote,
  });

  static const String table = 'user_business';

  final String? logo;
  final String? company;
  final String? document;
  final String? email;
  final String? phone;
  final String? address;
  final String? paymentInfo;
  final String? extraNote;

  factory UserBusiness.fromMap(Map<String, dynamic> map) {
    return UserBusiness(
      logo: map['logo'] as String?,
      company: map['company'] as String?,
      document: map['document'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      paymentInfo: map['payment_info'] as String?,
      extraNote: map['extra_note'] as String?,
    );
  }

  Map<String, dynamic> toMap(String userId) {
    return {
      'user_id': userId,
      'logo': logo,
      'company': company,
      'document': document,
      'email': email,
      'phone': phone,
      'address': address,
      'payment_info': paymentInfo,
      'extra_note': extraNote,
    };
  }
}
