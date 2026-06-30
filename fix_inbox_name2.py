import sys

file_path = r'd:\open\classifieds-app\frontend\lib\features\chat\presentation\widgets\inbox_thread_tile.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_fallback = '''       if (widget.thread.otherUserPhone != null && widget.thread.otherUserPhone!.isNotEmpty) {
          displayName = widget.thread.otherUserPhone!;
       } else if (widget.thread.otherUserName.isNotEmpty) {
          displayName = widget.thread.otherUserName;
       }'''

new_fallback = '''       if (widget.thread.otherUserPhone != null && widget.thread.otherUserPhone!.isNotEmpty) {
          displayName = widget.thread.otherUserPhone!;
       } else if (widget.thread.otherUserName.isNotEmpty && !isLoadingName && !widget.thread.otherUserName.toLowerCase().startsWith('user-')) {
          displayName = widget.thread.otherUserName;
       }'''

content = content.replace(old_fallback, new_fallback)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
