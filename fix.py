import sys

filepath = r'd:\open\classifieds-app\frontend\pubspec.yaml'
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

config = '''flutter_icons:
  android: true
  ios: true
  image_path: "assets/images/app_icon.png"
  remove_alpha_ios: true
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/images/app_icon.png"
'''

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(lines[:51])
    f.write('\n')
    f.write(config)
print('Fixed pubspec.yaml')
