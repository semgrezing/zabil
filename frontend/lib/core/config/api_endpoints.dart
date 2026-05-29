class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  // Users
  static const String usersSearch = '/users/search';
  static const String userMe = '/users/me';
  static const String userAvatar = '/users/me/avatar';

  // Groups
  static const String groups = '/groups';
  static String groupById(String id) => '/groups/$id';

  // Invitations
  static const String invitations = '/invitations';
  static const String incomingInvitations = '/invitations/incoming';
  static String acceptInvitation(String id) => '/invitations/$id/accept';
  static String declineInvitation(String id) => '/invitations/$id/decline';

  // Notes
  static const String notes = '/notes';
  static String noteById(String id) => '/notes/$id';
  static String archiveNote(String id) => '/notes/$id/archive';
  static String noteChecklist(String noteId) => '/notes/$noteId/checklist';
  static String checklistItem(String noteId, String itemId) => '/notes/$noteId/checklist/$itemId';

  // Uploads
  static const String uploadNoteImage = '/uploads/note-image';

  // Update
  static const String update = '/update';
}
