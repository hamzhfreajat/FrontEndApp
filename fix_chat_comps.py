import sys

file_path = r'd:\open\classifieds-app\frontend\lib\features\chat\presentation\widgets\chat_components.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_logic = '''    bool hasRealName = userName != null && 
                       userName!.trim().isNotEmpty && 
                       !userName!.toLowerCase().startsWith('user-') &&
                       userName != 'مستخدم' &&
                       userName != 'LOADING_NAME';
    
    bool isLoadingName = userName == 'LOADING_NAME';
    String displayName = 'مستخدم غير معروف';
    String? subtitlePhone;
    
    if (isLoadingName) {
       displayName = ''; // Handled by shimmer
    } else if (hasRealName) {
       displayName = userName!;
       if (userPhone != null && userPhone!.isNotEmpty) {
          subtitlePhone = userPhone;
       }
    } else {
       if (userPhone != null && userPhone!.isNotEmpty) {
          displayName = userPhone!;
       } else if (userName != null && userName!.isNotEmpty) {
          displayName = userName!;
       }
    }'''

new_logic = '''    bool isLoadingName = userName == 'LOADING_NAME';
    String displayName = 'مستخدم غير معروف';
    String? subtitlePhone;
    
    if (isLoadingName) {
       displayName = ''; // Handled by shimmer
    } else if (userName != null && userName!.trim().isNotEmpty) {
       displayName = userName!;
       if (userPhone != null && userPhone!.isNotEmpty) {
          subtitlePhone = userPhone;
       }
    } else {
       if (userPhone != null && userPhone!.isNotEmpty) {
          displayName = userPhone!;
       }
    }'''

content = content.replace(old_logic, new_logic)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
