class StoryUser {
  final int id;
  final String username;
  final String? avatarUrl;

  StoryUser({required this.id, required this.username, this.avatarUrl});

  factory StoryUser.fromJson(Map<String, dynamic> json) {
    return StoryUser(
      id: json['id'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
    );
  }
}

class Story {
  final int id;
  final int userId;
  final String imageUrl;
  final String? title;
  final String createdAt;
  final StoryUser? owner;

  Story({
    required this.id,
    required this.userId,
    required this.imageUrl,
    this.title,
    required this.createdAt,
    this.owner,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'],
      userId: json['user_id'],
      imageUrl: json['image_url'],
      title: json['title'],
      createdAt: json['created_at'],
      owner: json['owner'] != null ? StoryUser.fromJson(json['owner']) : null,
    );
  }
}
