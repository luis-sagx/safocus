/// Categorised map of default blocked sites.
/// Key = category label  ·  Value = list of domains.
abstract class BlockedSites {
  static const Map<String, List<String>> defaultByCategory = {
    'Redes sociales': [
      'facebook.com',
      'instagram.com',
      'tiktok.com',
      'twitter.com',
      'x.com',
      'snapchat.com',
      'pinterest.com',
      'reddit.com',
      'tumblr.com',
      'vk.com',
    ],
    'Adulto': [
      'pornhub.com',
      'xvideos.com',
      'xnxx.com',
      'redtube.com',
      'youporn.com',
      'brazzers.com',
      'xhamster.com',
      'tube8.com',
      'spankbang.com',
      'rule34.xxx',
      'xxxfollow.com',
    ],
    'Video / streaming': [
      'youtube.com',
      'twitch.tv',
      'netflix.com',
      'primevideo.com',
      'disneyplus.com',
      'hbo.com',
      'crunchyroll.com',
    ],
    'Apuestas / juegos': [
      'bet365.com',
      'pokerstars.com',
      'draftkings.com',
      'fanduel.com',
      'bovada.lv',
    ],
    'Noticias / clickbait': [
      'buzzfeed.com',
      'dailymail.co.uk',
      '9gag.com',
      'ladbible.com',
    ],
  };

  // Flat access
  static List<String> get allDefaults =>
      defaultByCategory.values.expand((l) => l).toList();
}
