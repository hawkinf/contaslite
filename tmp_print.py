from pathlib import Path
text = Path('packages/finance_app/lib/screens/dashboard_screen.dart').read_text(encoding='utf-8').splitlines()
for i in range(1330, 1435):
    print(f'{i+1}: {text[i]}')
