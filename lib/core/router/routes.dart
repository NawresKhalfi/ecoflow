/// Chemins de navigation de l'application.
abstract final class Routes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const phone = '/phone';
  static const forgotPassword = '/forgot-password';
  static const verifyEmail = '/verify-email';
  static const completeProfile = '/complete-profile';
  static const privacy = '/privacy';
  static const language = '/language';

  static const home = '/app';
  static const profile = '/app/profile';
  static const addresses = '/app/addresses';
  static const addressNew = '/app/addresses/new';
  static String addressEdit(String id) => '/app/addresses/$id';
  static const documents = '/app/documents';
  static const company = '/app/company';
  static const notifications = '/app/notifications';
  static const deleteAccount = '/app/delete-account';
  static const scan = '/app/scan';
  static const catalog = '/app/catalog';
  static const model = '/app/model';
  static const estimates = '/app/estimates';
  static String estimateDetail(String code) => '/app/estimates/$code';
  static const weighing = '/app/weighing';
  static const pricing = '/app/pricing';
  static const collections = '/app/collections';
  static String collectionNew(String estimateCode) => '/app/collections/new/$estimateCode';
  static String collectionDetail(String id) => '/app/collections/$id';
  static const missions = '/app/missions';
  static String missionDetail(String id) => '/app/missions/$id';
  static const earnings = '/app/earnings';
  static const deposit = '/app/earnings/deposit';
  static const vehicle = '/app/vehicle';
  static const receptions = '/app/receptions';
  static const tour = '/app/missions/tour';
  static const optimization = '/app/optimization';
  static const inbox = '/app/inbox';
  static String chat(String collectionId) => '/app/chat/$collectionId';
  static const wallet = '/app/wallet';
  static const walletRewards = '/app/wallet/rewards';
  static const walletCoupons = '/app/wallet/coupons';
  static const pointsRules = '/app/points-rules';
  static const rewardsAdmin = '/app/rewards-admin';
  static const fraud = '/app/fraud';
  static const dashboard = '/app/dashboard';
  static const stock = '/app/stock';
  static String lotDetail(String id) => '/app/stock/$id';
  static const purchasing = '/app/purchasing';

  /// Accessibles sans être connecté.
  static const public = {welcome, signIn, signUp, phone, forgotPassword};

  /// Accessibles dans tous les états de session.
  static const always = {privacy, language};
}
