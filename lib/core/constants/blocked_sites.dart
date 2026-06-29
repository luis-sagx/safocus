/// Categorised map of default VPN-blocked sites.
///
/// DESIGN RULE: Only include domains that users navigate to INTENTIONALLY and
/// that are never embedded as third-party content on normal websites.
/// Social media (facebook, youtube, instagram, twitter) are intentionally
/// excluded — they appear as embeds on virtually every website and DNS-blocking
/// them causes false positives ("site can't be reached") on unrelated pages.
/// Social media apps are controlled via App Limits (time-based), not DNS.
abstract class BlockedSites {
  static const Map<String, List<String>> defaultByCategory = {
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
      'beeg.com',
      'hentaihaven.xxx',
      'nhentai.net',
      'erome.com',
      'motherless.com',
      'porntrex.com',
      'tnaflix.com',
      'faphouse.com',
    ],
    'Apuestas / juegos': [
      'bet365.com',
      'pokerstars.com',
      'draftkings.com',
      'fanduel.com',
      'bovada.lv',
      'betway.com',
      '1xbet.com',
      'williamhill.com',
      'bwin.com',
      'unibet.com',
      'betsson.com',
      'codere.com',
      'sportingbet.com',
      'marathonbet.com',
      'betcris.com',
      'inkabet.com',
      'apuesta.pe',
      'retabet.com',
      'coolbet.com',
      'winamax.fr',
      'ladbrokes.com',
      'coral.co.uk',
      'betfair.com',
      'partypoker.com',
      'casino.com',
      '888casino.com',
      '888sport.com',
      'leovegas.com',
      'betonline.ag',
      'mybookie.ag',
      'stake.com',
      'roobet.com',
      'rollbit.com',
      'ecuabet.com',
      'betano.com',
      'rushbet.co',
      'wplay.co',
      'rivalo.com',
      '1win.com',
      'melbet.com',
      'betwinner.com',
      'megapari.com',
      'pin-up.bet',
      'betsafe.com',
      'meridianbet.com',
    ],
    'Noticias / clickbait': [
      'buzzfeed.com',
      'dailymail.co.uk',
      '9gag.com',
      'ladbible.com',
      'thechive.com',
      'viralthread.com',
      'boredpanda.com',
    ],
  };

  // Flat access
  static List<String> get allDefaults =>
      defaultByCategory.values.expand((l) => l).toList();

  static String localizedCategory(String category, String languageCode) {
    final isEnglish = languageCode.toLowerCase().startsWith('en');
    switch (category) {
      case 'Adulto':
        return isEnglish ? 'Adult' : category;
      case 'Apuestas / juegos':
        return isEnglish ? 'Betting / games' : category;
      case 'Noticias / clickbait':
        return isEnglish ? 'News / clickbait' : category;
      default:
        return category;
    }
  }
}
