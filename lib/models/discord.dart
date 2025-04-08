class DiscordUser {
  String? id;
  String? username;
  String? discriminator;
  String? avatar;
  bool? verified;
  String? email;
  int? flags;
  String? banner;
  int? accentColor;
  int? premiumType;
  int? publicFlags;
  AvatarDecorationData? avatarDecorationData;

  DiscordUser({
    this.id,
    this.username,
    this.discriminator,
    this.avatar,
    this.verified,
    this.email,
    this.flags,
    this.banner,
    this.accentColor,
    this.premiumType,
    this.publicFlags,
    this.avatarDecorationData,
  });

  DiscordUser.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    username = json['username'];
    discriminator = json['discriminator'];
    avatar = json['avatar'];
    verified = json['verified'];
    email = json['email'];
    flags = json['flags'];
    banner = json['banner'];
    accentColor = json['accent_color'];
    premiumType = json['premium_type'];
    publicFlags = json['public_flags'];
    avatarDecorationData =
        json['avatar_decoration_data'] != null
            ? new AvatarDecorationData.fromJson(json['avatar_decoration_data'])
            : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['username'] = this.username;
    data['discriminator'] = this.discriminator;
    data['avatar'] = this.avatar;
    data['verified'] = this.verified;
    data['email'] = this.email;
    data['flags'] = this.flags;
    data['banner'] = this.banner;
    data['accent_color'] = this.accentColor;
    data['premium_type'] = this.premiumType;
    data['public_flags'] = this.publicFlags;
    if (this.avatarDecorationData != null) {
      data['avatar_decoration_data'] = this.avatarDecorationData!.toJson();
    }
    return data;
  }
}

class AvatarDecorationData {
  String? skuId;
  String? asset;

  AvatarDecorationData({this.skuId, this.asset});

  AvatarDecorationData.fromJson(Map<String, dynamic> json) {
    skuId = json['sku_id'];
    asset = json['asset'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['sku_id'] = this.skuId;
    data['asset'] = this.asset;
    return data;
  }
}
