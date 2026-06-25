const fs = require('fs');
const path = require('path');
const dir = 'D:/open/classifieds-app/frontend/lib/screens';
const files = fs.readdirSync(dir).filter(f => f.startsWith('add_ad_') && f.endsWith('.dart'));

files.forEach(f => {
    const filePath = path.join(dir, f);
    let content = fs.readFileSync(filePath, 'utf8');
    if (!content.includes('SupportActionButton')) {
        content = content.replace(/(import 'package:flutter\/material\.dart';)/, "$1\nimport '../widgets/support_action_button.dart';");
        content = content.replace(/(centerTitle:\s*(true|false),)/g, "$1\n        actions: const [SupportActionButton()],");
        fs.writeFileSync(filePath, content);
        console.log('Updated ' + f);
    }
});
