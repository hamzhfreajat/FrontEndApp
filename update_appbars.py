import os
import re

directory = 'D:/open/classifieds-app/frontend/lib/screens'

for filename in os.listdir(directory):
    if filename.startswith('add_ad_') and filename.endswith('.dart'):
        filepath = os.path.join(directory, filename)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        if 'SupportActionButton' not in content:
            # add import
            import_statement = "
import '../widgets/support_action_button.dart';
"
            content = re.sub(r'(import ''package:flutter/material\.dart'';)', r'\1' + import_statement, content)
            
            # add action
            # Find centerTitle: true, or centerTitle: false, or elevation: X,
            # and insert actions: const [SupportActionButton()],
            content = re.sub(r'(centerTitle:\s*(true|false),)', r'\1\n        actions: const [SupportActionButton()],', content)
            
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f'Updated {filename}')
