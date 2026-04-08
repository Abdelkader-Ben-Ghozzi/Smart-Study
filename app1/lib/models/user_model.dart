class UserModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
    );
  }

  String get firstName => name.split(' ').first;

  String? avatarUrl({
    String base =
        'https://kasandra-unmeddled-heriberto.ngrok-free.dev/storage/',
  }) {
    if (avatar == null || avatar!.isEmpty) return null;
    return '$base$avatar';
  }
}
