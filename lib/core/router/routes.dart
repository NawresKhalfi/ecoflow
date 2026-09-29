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

  /// Accessibles sans être connecté.
  static const public = {welcome, signIn, signUp, phone, forgotPassword};

  /// Accessibles dans tous les états de session.
  static const always = {privacy, language};
}
