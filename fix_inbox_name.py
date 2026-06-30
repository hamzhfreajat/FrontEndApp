import sys

file_path = r'd:\open\classifieds-app\frontend\lib\features\chat\presentation\widgets\inbox_thread_tile.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_logic = '''    bool hasRealName = widget.thread.otherUserName.isNotEmpty && 
                       !widget.thread.otherUserName.toLowerCase().startsWith('user-') &&
                       widget.thread.otherUserName != 'مستخدم';'''

new_logic = '''    bool isLoadingName = widget.thread.otherUserName == 'LOADING_NAME';
    bool hasRealName = widget.thread.otherUserName.isNotEmpty && 
                       !widget.thread.otherUserName.toLowerCase().startsWith('user-') &&
                       widget.thread.otherUserName != 'مستخدم' &&
                       !isLoadingName;'''

content = content.replace(old_logic, new_logic)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
