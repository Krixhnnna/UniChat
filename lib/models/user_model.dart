class UserModel {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String? bio;
  final int? age;
  final String? gender;
  final List<String>? interests;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.bio,
    this.age,
    this.gender,
    this.interests,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      bio: map['bio'],
      age: map['age'],
      gender: map['gender'],
      interests: map['interests'] != null ? List<String>.from(map['interests']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'bio': bio,
      'age': age,
      'gender': gender,
      'interests': interests,
    };
  }
} 