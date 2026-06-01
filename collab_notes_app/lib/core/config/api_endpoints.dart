class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String telegramStart = '/auth/telegram/start';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  // Users
  static const String usersSearch = '/users/search';
  static const String userMe = '/users/me';
  static String userPublicProfile(String id) => '/users/$id/profile';
  static String userOnlineStatus(String id) => '/users/$id/online-status';
  static const String userAvatar = '/users/me/avatar';
  static const String userAvatarHistory = '/users/me/avatar/history';
  static String userAvatarHistoryItem(String historyId) => '/users/me/avatar/history/$historyId';

  // Groups
  static const String groups = '/groups';
  static const String groupsPersonalContext = '/groups/personal-context';
  static String groupById(String id) => '/groups/$id';
  static String updateGroup(String id) => '/groups/$id';
  static String leaveGroup(String id) => '/groups/$id/leave';
  static String deleteGroup(String id) => '/groups/$id';
  static String removeGroupMember(String groupId, String userId) => '/groups/$groupId/members/$userId';
  static String groupAvatar(String groupId) => '/groups/$groupId/avatar';
  static String groupAvatarHistory(String groupId) => '/groups/$groupId/avatar/history';
  static String groupAvatarHistoryItem(String groupId, String historyId) =>
      '/groups/$groupId/avatar/history/$historyId';

  // Invitations
  static const String invitations = '/invitations';
  static const String incomingInvitations = '/invitations/incoming';
  static String groupPendingInvitations(String groupId) =>
      '/invitations/group/$groupId/pending';
  static String acceptInvitation(String id) => '/invitations/$id/accept';
  static String declineInvitation(String id) => '/invitations/$id/decline';

  // Notes
  static const String notes = '/notes';
  static String noteById(String id) => '/notes/$id';
  static String moveNote(String id) => '/notes/$id/move';
  static String archiveNote(String id) => '/notes/$id/archive';
  static String noteChecklist(String noteId) => '/notes/$noteId/checklist';
  static String checklistItem(String noteId, String itemId) => '/notes/$noteId/checklist/$itemId';
  static String noteBlocks(String noteId) => '/notes/$noteId/blocks';
  static String noteBlock(String noteId, String blockId) => '/notes/$noteId/blocks/$blockId';
  static String reorderNoteBlocks(String noteId) => '/notes/$noteId/blocks/reorder';

  // Uploads
  static const String uploadNoteImage = '/uploads/note-image';
  static const String uploadChatImage = '/uploads/chat-image';
  static String deleteNoteImage(String imageId) => '/uploads/note-image/$imageId';

  // Update
  static const String update = '/update';

  // Notifications / device tokens
  static const String registerDevice = '/devices/register';
  static String unregisterDevice(String tokenId) => '/devices/$tokenId';

  // Activity feed
  static const String activityFeed = '/activity/feed';

  // Mentions
  static const String mentions = '/mentions';
  static const String mentionsReadAll = '/mentions/read-all';

  // Chats (Stage 7)
  static String groupChatMessages(String groupId) => '/chats/groups/$groupId/messages';
  static String deleteGroupMessage(String groupId, String messageId) => '/chats/groups/$groupId/messages/$messageId';
  static const String personalChats = '/chats/personal';
  static String personalMessages(String userId) => '/chats/personal/$userId/messages';
  static String deletePersonalMessage(String userId, String messageId) => '/chats/personal/$userId/messages/$messageId';
  static String personalMarkRead(String userId) => '/chats/personal/$userId/read';
  static String groupMarkRead(String groupId) => '/chats/groups/$groupId/read';
}
