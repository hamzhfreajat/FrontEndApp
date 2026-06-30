import sys

file_path = r'd:\open\classifieds-app\frontend\lib\features\chat\presentation\widgets\inbox_thread_tile.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_logic = '''    bool isLoadingName = widget.thread.otherUserName == 'LOADING_NAME';
    bool hasRealName = widget.thread.otherUserName.isNotEmpty && 
                       !widget.thread.otherUserName.toLowerCase().startsWith('user-') &&
                       widget.thread.otherUserName != 'مستخدم' &&
                       !isLoadingName;
                       
    String displayName = 'مستخدم';
    String? subtitlePhone;
    
    final bool isSupportChat = widget.thread.adId == 'support' || widget.thread.otherUserId == 'admin';

    if (isSupportChat) {
       displayName = 'فريق الدعم الفني';
       subtitlePhone = null;
    } else if (hasRealName) {
       displayName = widget.thread.otherUserName;
       if (widget.thread.otherUserPhone != null && widget.thread.otherUserPhone!.isNotEmpty) {
          subtitlePhone = widget.thread.otherUserPhone;
       }
    } else {
       if (widget.thread.otherUserPhone != null && widget.thread.otherUserPhone!.isNotEmpty) {
          displayName = widget.thread.otherUserPhone!;
       } else if (widget.thread.otherUserName.isNotEmpty && !isLoadingName && !widget.thread.otherUserName.toLowerCase().startsWith('user-')) {
          displayName = widget.thread.otherUserName;
       }
    }'''

new_logic = '''    bool isLoadingName = widget.thread.otherUserName == 'LOADING_NAME';
    String displayName = 'مستخدم';
    String? subtitlePhone;
    
    final bool isSupportChat = widget.thread.adId == 'support' || widget.thread.otherUserId == 'admin';

    if (isSupportChat) {
       displayName = 'فريق الدعم الفني';
       subtitlePhone = null;
    } else if (widget.thread.otherUserName.isNotEmpty && !isLoadingName) {
       displayName = widget.thread.otherUserName;
       if (widget.thread.otherUserPhone != null && widget.thread.otherUserPhone!.isNotEmpty) {
          subtitlePhone = widget.thread.otherUserPhone;
       }
    } else {
       if (widget.thread.otherUserPhone != null && widget.thread.otherUserPhone!.isNotEmpty) {
          displayName = widget.thread.otherUserPhone!;
       }
    }'''

content = content.replace(old_logic, new_logic)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
